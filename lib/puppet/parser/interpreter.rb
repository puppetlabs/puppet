# The interepreter's job is to convert from a parsed file to the configuration
# for a given client.  It really doesn't do any work on its own, it just collects
# and calls out to other objects.

require 'puppet'
require 'puppet/parser/parser'
require 'puppet/parser/scope'


module Puppet
    module Parser
        class Interpreter
            Puppet.setdefaults("ldap",
                [:ldapnodes, false,
                    "Whether to search for node configurations in LDAP."],
                [:ldapserver, "ldap",
                    "The LDAP server.  Only used if ``ldapnodes`` is enabled."],
                [:ldapport, 389,
                    "The LDAP port.  Only used if ``ldapnodes`` is enabled."],
                [:ldapstring, "(&(objectclass=puppetClient)(cn=%s))",
                    "The search string used to find an LDAP node."],
                [:ldapattrs, "puppetclass",
                    "The LDAP attributes to use to define Puppet classes.  Values
                    should be comma-separated."],
                [:ldapparentattr, "parentnode",
                    "The attribute to use to define the parent node."],
                [:ldapuser, "",
                    "The user to use to connect to LDAP.  Must be specified as a
                    full DN."],
                [:ldappassword, "",
                    "The password to use to connect to LDAP."],
                [:ldapbase, "",
                    "The search base for LDAP searches.  It's impossible to provide
                    a meaningful default here, although the LDAP libraries might
                    have one already set.  Generally, it should be the 'ou=Hosts'
                    branch under your main directory."]
            )

            attr_accessor :ast, :filetimeout
            # just shorten the constant path a bit, using what amounts to an alias
            AST = Puppet::Parser::AST

            # create our interpreter
            def initialize(hash)
                unless hash.include?(:Manifest)
                    raise Puppet::DevError, "Interpreter was not passed a manifest"
                end

                @file = hash[:Manifest]
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

                # Create our parser object
                parsefiles

                evaluate
            end

            # Connect to the LDAP Server
            def setup_ldap
                begin
                    require 'ldap'
                rescue LoadError
                    @ldap = nil
                end
                begin
                    @ldap = LDAP::Conn.new(Puppet[:ldapserver], Puppet[:ldapport])
                    @ldap.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
                    @ldap.simple_bind(Puppet[:ldapuser], Puppet[:ldappassword])
                rescue => detail
                    raise Puppet::Error, "Could not connect to LDAP: %s" % detail
                end
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

                # if the client name is fully qualied (which is normally will be)
                # add the short name
                if client =~ /\./
                    names << client.sub(/\..+/,'')
                end

                begin
                    if @usenodes
                        unless client
                            raise Puppet::Error,
                                "Cannot evaluate nodes with a nil client"
                        end

                        classes = nil
                        parent = nil
                        # At this point, stop at the first source that defines
                        # the node
                        @nodesources.each do |source|
                            method = "nodesearch_%s" % source
                            if self.respond_to? method
                                parent, classes = self.send(method, client)
                            end

                            if classes
                                Puppet.info "Found %s in %s" % [client, source]
                                break
                            end
                        end

                        # We've already evaluated the AST, in this case
                        #return @scope.evalnode(names, facts, classes, parent)
                        return @scope.evalnode(
                            :name => names,
                            :facts => facts,
                            :classes => classes,
                            :parent => parent
                        )
                    else
                        # We've already evaluated the AST, in this case
                        @scope = Puppet::Parser::Scope.new() # no parent scope
                        @scope.interp = self
                        #return @scope.evaluate(@ast, facts, @classes)
                        return @scope.evaluate(
                            :ast => @ast,
                            :facts => facts,
                            :classes => @classes
                        )
                    end
                    #@ast.evaluate(@scope)
                rescue Puppet::DevError, Puppet::Error, Puppet::ParseError => except
                    #Puppet.err "File %s, line %s: %s" %
                    #    [except.file, except.line, except.message]
                    if Puppet[:debug]
                        puts except.backtrace
                    end
                    #exit(1)
                    raise
                rescue => except
                    error = Puppet::DevError.new("%s: %s" %
                        [except.class, except.message])
                    if Puppet[:debug]
                        puts except.backtrace
                    end
                    raise error
                end
            end

            def scope
                return @scope
            end

            private

            # Evaluate the configuration.  If there aren't any nodes defined, then
            # this doesn't actually do anything, because we have to evaluate the
            # entire configuration each time we get a connect.
            def evaluate
                # FIXME When this produces errors, it should specify which
                # node caused those errors.
                if @usenodes
                    @scope = Puppet::Parser::Scope.new() # no parent scope
                    @scope.name = "top"
                    @scope.type = "puppet"
                    @scope.interp = self
                    Puppet.debug "Nodes defined"
                    @ast.safeevaluate(:scope => @scope)
                else
                    Puppet.debug "No nodes defined"
                    return
                end
            end

            def parsefiles
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

                if defined? @parser
                    Puppet.info "Reloading files"
                end
                # should i be creating a new parser each time...?
                @parser = Puppet::Parser::Parser.new()
                @parser.file = @file
                @ast = @parser.parse

                # Mark when we parsed, so we can check freshness
                @parsedate = Time.now.to_i
                @lastchecked = Time.now

                # Reevaluate the config.  This is what actually replaces the
                # existing scope.
                evaluate
            end
        end
    end
end

# $Id$
