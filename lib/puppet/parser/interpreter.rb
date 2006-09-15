# The interepreter's job is to convert from a parsed file to the configuration
# for a given client.  It really doesn't do any work on its own, it just collects
# and calls out to other objects.

require 'puppet'
require 'puppet/parser/parser'
require 'puppet/parser/scope'


module Puppet
    module Parser
        class Interpreter
            include Puppet::Util

            Puppet.setdefaults("ldap",
                :ldapnodes => [false,
                    "Whether to search for node configurations in LDAP."],
                :ldapssl => [false,
                    "Whether SSL should be used when searching for nodes.
                    Defaults to false because SSL usually requires certificates
                    to be set up on the client side."],
                :ldaptls => [false,
                    "Whether TLS should be used when searching for nodes.
                    Defaults to false because TLS usually requires certificates
                    to be set up on the client side."],
                :ldapserver => ["ldap",
                    "The LDAP server.  Only used if ``ldapnodes`` is enabled."],
                :ldapport => [389,
                    "The LDAP port.  Only used if ``ldapnodes`` is enabled."],
                :ldapstring => ["(&(objectclass=puppetClient)(cn=%s))",
                    "The search string used to find an LDAP node."],
                :ldapattrs => ["puppetclass",
                    "The LDAP attributes to use to define Puppet classes.  Values
                    should be comma-separated."],
                :ldapparentattr => ["parentnode",
                    "The attribute to use to define the parent node."],
                :ldapuser => ["",
                    "The user to use to connect to LDAP.  Must be specified as a
                    full DN."],
                :ldappassword => ["",
                    "The password to use to connect to LDAP."],
                :ldapbase => ["",
                    "The search base for LDAP searches.  It's impossible to provide
                    a meaningful default here, although the LDAP libraries might
                    have one already set.  Generally, it should be the 'ou=Hosts'
                    branch under your main directory."]
            )

            Puppet.setdefaults(:puppetmaster,
                :storeconfigs => [false,
                    "Whether to store each client's configuration.  This
                     requires ActiveRecord from Ruby on Rails."]
            )

            attr_accessor :ast

            class << self
                attr_writer :ldap
            end
            # just shorten the constant path a bit, using what amounts to an alias
            AST = Puppet::Parser::AST

            # Create an ldap connection.  This is a class method so others can call
            # it and use the same variables and such.
            def self.ldap
                unless defined? @ldap and @ldap
                    if Puppet[:ldapssl]
                        @ldap = LDAP::SSLConn.new(Puppet[:ldapserver], Puppet[:ldapport])
                    elsif Puppet[:ldaptls]
                        @ldap = LDAP::SSLConn.new(
                            Puppet[:ldapserver], Puppet[:ldapport], true
                        )
                    else
                        @ldap = LDAP::Conn.new(Puppet[:ldapserver], Puppet[:ldapport])
                    end
                    @ldap.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
                    @ldap.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
                    @ldap.simple_bind(Puppet[:ldapuser], Puppet[:ldappassword])
                end

                return @ldap
            end

            # create our interpreter
            def initialize(hash)
                if @code = hash[:Code]
                    @file = nil # to avoid warnings
                elsif ! @file = hash[:Manifest]
                    raise Puppet::DevError, "You must provide code or a manifest"
                end

                @lastchecked = 0

                if hash.include?(:UseNodes)
                    @usenodes = hash[:UseNodes]
                else
                    @usenodes = true
                end

                # By default, we only search the parse tree.
                @nodesources = []

                if Puppet[:ldapnodes]
                    @nodesources << :ldap
                end

                if hash[:NodeSources]
                    hash[:NodeSources].each do |src|
                        if respond_to? "nodesearch_#{src.to_s}"
                            @nodesources << src.to_s.intern
                        else
                            Puppet.warning "Node source '#{src}' not supported"
                        end
                    end
                end

                @setup = false

                # Set it to either the value or nil.  This is currently only used
                # by the cfengine module.
                @classes = hash[:Classes] || []

                @local = hash[:Local] || false

                if hash.include?(:ForkSave)
                    @forksave = hash[:ForkSave]
                else
                    # This is just too dangerous right now.  Sorry, it's going
                    # to have to be slow.
                    @forksave = false
                end

                if Puppet[:storeconfigs]
                    Puppet::Rails.init
                end

                @files = []

                # Create our parser object
                parsefiles
            end

            # Search for our node in the various locations.  This only searches
            # locations external to the files; the scope is responsible for
            # searching the parse tree.
            def nodesearch(*nodes)
                # At this point, stop at the first source that defines
                # the node
                @nodesources.each do |source|
                    method = "nodesearch_%s" % source
                    parent = nil
                    nodeclasses = nil
                    if self.respond_to? method
                        nodes.each do |node|
                            parent, nodeclasses = self.send(method, node)

                            if parent or (nodeclasses and !nodeclasses.empty?)
                                Puppet.info "Found %s in %s" % [node, source]
                                return parent, nodeclasses
                            else
                                # Look for a default node.
                                parent, nodeclasses = self.send(method, "default")
                                if parent or (nodeclasses and !nodeclasses.empty?)
                                    Puppet.info "Found default node for %s in %s" %
                                        [node, source]
                                    return parent, nodeclasses
                                end
                            end
                        end
                    end
                end

                return nil, nil
            end

            # Find the ldap node and extra the info, returning just
            # the critical data.
            def nodesearch_ldap(node)
                unless defined? @ldap and @ldap
                    setup_ldap()
                    unless @ldap
                        Puppet.info "Skipping ldap source; no ldap connection"
                        return nil, []
                    end
                end

                if node =~ /\./
                    node = node.sub(/\..+/, '')
                end

                filter = Puppet[:ldapstring]
                attrs = Puppet[:ldapattrs].split("\s*,\s*")
                sattrs = attrs.dup
                pattr = nil
                if pattr = Puppet[:ldapparentattr]
                    if pattr == ""
                        pattr = nil
                    else
                        sattrs << pattr
                    end
                end

                if filter =~ /%s/
                    filter = filter.gsub(/%s/, node)
                end

                parent = nil
                classes = []

                found = false
                count = 0
                begin
                    # We're always doing a sub here; oh well.
                    @ldap.search(Puppet[:ldapbase], 2, filter, sattrs) do |entry|
                        found = true
                        if pattr
                            if values = entry.vals(pattr)
                                if values.length > 1
                                    raise Puppet::Error,
                                        "Node %s has more than one parent: %s" %
                                        [node, values.inspect]
                                end
                                unless values.empty?
                                    parent = values.shift
                                end
                            end
                        end

                        attrs.each { |attr|
                            if values = entry.vals(attr)
                                values.each do |v| classes << v end
                            end
                        }
                    end
                rescue => detail
                    if count == 0
                        # Try reconnecting to ldap
                        @ldap = nil
                        setup_ldap()
                        retry
                    else
                        raise Puppet::Error, "LDAP Search failed: %s" % detail
                    end
                end

                classes.flatten!

                return parent, classes
            end

            def parsedate
                parsefiles()
                @parsedate
            end

            # Add a new file to check for updateness.
            def newfile(file)
                unless @files.find { |f| f.file == file }
                    @files << Puppet::LoadedFile.new(file)
                end
            end

            # evaluate our whole tree
            def run(client, facts)
                # We have to leave this for after initialization because there
                # seems to be a problem keeping ldap open after a fork.
                unless @setup
                    @nodesources.each { |source|
                        method = "setup_%s" % source.to_s
                        if respond_to? method
                            begin
                                self.send(method)
                            rescue => detail
                                raise Puppet::Error,
                                    "Could not set up node source %s" % source
                            end
                        end
                    }
                end
                parsefiles()

                # Really, we should stick multiple names in here
                # but for now just make a simple array
                names = [client]

                # Make sure both the fqdn and the short name of the
                # host can be used in the manifest
                if client =~ /\./
                    names << client.sub(/\..+/,'')
                else
                    names << "#{client}.#{facts['domain']}"
                end

                scope = Puppet::Parser::Scope.new() # no parent scope
                scope.name = "top"
                scope.type = "puppet"
                scope.interp = self

                classes = @classes.dup

                args = {:ast => @ast, :facts => facts, :classes => classes}

                if @usenodes
                    unless client
                        raise Puppet::Error,
                            "Cannot evaluate nodes with a nil client"
                    end

                    args[:names] = names

                    parent, nodeclasses = nodesearch(*names)

                    args[:classes] += nodeclasses if nodeclasses

                    args[:parentnode] = parent if parent

                    if nodeclasses or parent
                        args[:searched] = true
                    end
                end

                begin
                    objects = scope.evaluate(args)
                rescue Puppet::DevError, Puppet::Error, Puppet::ParseError => except
                    raise
                rescue => except
                    error = Puppet::DevError.new("%s: %s" %
                        [except.class, except.message])
                    error.set_backtrace except.backtrace
                    raise error
                end

                if Puppet[:storeconfigs]
                    storeconfigs(
                        :objects => objects,
                        :host => client,
                        :facts => facts
                    )
                end

                return objects
            end

            # Connect to the LDAP Server
            def setup_ldap
                self.class.ldap = nil
                begin
                    require 'ldap'
                rescue LoadError
                    Puppet.notice(
                        "Could not set up LDAP Connection: Missing ruby/ldap libraries"
                    )
                    @ldap = nil
                    return
                end
                begin
                    @ldap = self.class.ldap()
                rescue => detail
                    raise Puppet::Error, "Could not connect to LDAP: %s" % detail
                end
            end

            def scope
                return @scope
            end

            private

            # Check whether any of our files have changed.
            def checkfiles
                if @files.find { |f| f.changed?  }
                    @parsedate = Time.now.to_i
                end
            end

            # Parse the files, generating our parse tree.  This automatically
            # reparses only if files are updated, so it's safe to call multiple
            # times.
            def parsefiles
                # First check whether there are updates to any non-puppet files
                # like templates.  If we need to reparse, this will get quashed,
                # but it needs to be done first in case there's no reparse
                # but there are other file changes.
                checkfiles()

                # Check if the parser should reparse.
                if @file
                    if defined? @parser
                        unless @parser.reparse?
                            @lastchecked = Time.now
                            return false
                        end
                    end

                    unless FileTest.exists?(@file)
                        if @ast
                            return
                        else
                            raise Puppet::Error, "Manifest %s must exist" % @file
                        end
                    end
                end

                if defined? @parser
                    # If this isn't our first time parsing in this process,
                    # note that we're reparsing.
                    Puppet.info "Reloading files"
                end
                # should i be creating a new parser each time...?
                @parser = Puppet::Parser::Parser.new()
                if @code
                    @parser.string = @code
                else
                    @parser.file = @file
                end

                if @local
                    @ast = @parser.parse
                else
                    benchmark(:info, "Parsed manifest") do
                        @ast = @parser.parse
                    end
                end

                # Mark when we parsed, so we can check freshness
                @parsedate = Time.now.to_i
                @lastchecked = Time.now
            end

            # Store the configs into the database.
            def storeconfigs(hash)
                unless defined? ActiveRecord
                    require 'puppet/rails'
                    unless defined? ActiveRecord
                        raise LoadError,
                            "storeconfigs is enabled but rails is unavailable"
                    end
                end

                Puppet::Rails.init

                # Fork the storage, since we don't need the client waiting
                # on that.  How do I avoid this duplication?
                if @forksave
                    fork {
                        # We store all of the objects, even the collectable ones
                        benchmark(:info, "Stored configuration for #{hash[:client]}") do
                            # Try to batch things a bit, by putting them into
                            # a transaction
                            Puppet::Rails::Host.transaction do
                                Puppet::Rails::Host.store(hash)
                            end
                        end
                    }
                else
                    # We store all of the objects, even the collectable ones
                    benchmark(:info, "Stored configuration for #{hash[:client]}") do
                        Puppet::Rails::Host.transaction do
                            Puppet::Rails::Host.store(hash)
                        end
                    end
                end

                # Now that we've stored everything, we need to strip out
                # the collectable objects so that they are not sent on
                # to the host
                hash[:objects].collectstrip!
            end
        end
    end
end

# $Id$
