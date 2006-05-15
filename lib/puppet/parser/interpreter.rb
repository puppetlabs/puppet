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

            attr_accessor :ast, :filetimeout
            # just shorten the constant path a bit, using what amounts to an alias
            AST = Puppet::Parser::AST

            # create our interpreter
            def initialize(hash)
                if @code = hash[:Code]
                    @file = nil # to avoid warnings
                elsif ! @file = hash[:Manifest]
                    raise Puppet::DevError, "You must provide code or a manifest"
                end
                @filetimeout = hash[:ParseCheck] || 15

                @lastchecked = 0

                if hash.include?(:UseNodes)
                    @usenodes = hash[:UseNodes]
                else
                    @usenodes = true
                end

                @nodesources = hash[:NodeSources] || [:file]

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

                # Create our parser object
                parsefiles
            end

            # Connect to the LDAP Server
            def setup_ldap
                begin
                    require 'ldap'
                rescue LoadError
                    @ldap = nil
                    return
                end
                begin
                    @ldap = LDAP::Conn.new(Puppet[:ldapserver], Puppet[:ldapport])
                    @ldap.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
                    @ldap.simple_bind(Puppet[:ldapuser], Puppet[:ldappassword])
                rescue => detail
                    raise Puppet::Error, "Could not connect to LDAP: %s" % detail
                end
            end

            # Search for our node in the various locations.
            def nodesearch(node)
                # At this point, stop at the first source that defines
                # the node
                @nodesources.each do |source|
                    method = "nodesearch_%s" % source
                    if self.respond_to? method
                        parent, nodeclasses = self.send(method, node)
                    end

                    if nodeclasses
                        Puppet.info "Found %s in %s" % [node, source]
                        return parent, nodeclasses
                    end
                end

                return nil, nil
            end

            # Find the ldap node and extra the info, returning just
            # the critical data.
            def nodesearch_ldap(node)
                unless defined? @ldap
                    ldapconnect()
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
                            classes += values
                        end
                    }
                end

                classes.flatten!

                return parent, classes
            end

            def parsedate
                parsefiles()
                @parsedate
            end

            # evaluate our whole tree
            def run(client, facts)
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

                    parent, nodeclasses = nodesearch(client)

                    args[:classes] += nodeclasses if nodeclasses

                    args[:parentnode] = parent if parent
                end

                begin
                    objects = scope.evaluate(args)
                rescue Puppet::DevError, Puppet::Error, Puppet::ParseError => except
                    raise
                rescue => except
                    error = Puppet::DevError.new("%s: %s" %
                        [except.class, except.message])
                    error.backtrace = except.backtrace
                    #if Puppet[:debug]
                    #    puts except.backtrace
                    #end
                    raise error
                end

                if Puppet[:storeconfigs]
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
                            benchmark(:info, "Stored configuration for #{client}") do
                                # Try to batch things a bit, by putting them into
                                # a transaction
                                Puppet::Rails::Host.transaction do
                                    Puppet::Rails::Host.store(
                                        :objects => objects,
                                        :host => client,
                                        :facts => facts
                                    )
                                end
                            end
                        }
                    else
                        # We store all of the objects, even the collectable ones
                        benchmark(:info, "Stored configuration for #{client}") do
                            Puppet::Rails::Host.transaction do
                                Puppet::Rails::Host.store(
                                    :objects => objects,
                                    :host => client,
                                    :facts => facts
                                )
                            end
                        end
                    end

                    # Now that we've stored everything, we need to strip out
                    # the collectable objects so that they are not sent on
                    # to the host
                    objects.collectstrip!
                end

                return objects
            end

            def scope
                return @scope
            end

            private

            def parsefiles
                if @file
                    if defined? @parser
                        # Only check the files every 15 seconds or so, not on
                        # every single connection
                        if (Time.now - @lastchecked).to_i >= @filetimeout.to_i
                            unless @parser.reparse?
                                @lastchecked = Time.now
                                return false
                            end
                        else
                            return
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
                    @ast = benchmark(:info, "Parsed manifest") do
                        @parser.parse
                    end
                end

                # Mark when we parsed, so we can check freshness
                @parsedate = Time.now.to_i
                @lastchecked = Time.now
            end
        end
    end
end

# $Id$
