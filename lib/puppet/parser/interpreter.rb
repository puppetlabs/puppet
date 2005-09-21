# The interepreter's job is to convert from a parsed file to the configuration
# for a given client.  It really doesn't do any work on its own, it just collects
# and calls out to other objects.

require 'puppet'
require 'puppet/parser/parser'
require 'puppet/parser/scope'


module Puppet
    module Parser
        class Interpreter
            attr_accessor :ast, :topscope
            # just shorten the constant path a bit, using what amounts to an alias
            AST = Puppet::Parser::AST

            # create our interpreter
            def initialize(hash)
                unless hash.include?(:Manifest)
                    raise Puppet::DevError, "Interpreter was not passed a file"
                end

                @file = hash[:Manifest]

                if hash.include?(:UseNodes)
                    @usenodes = hash[:UseNodes]
                else
                    @usenodes = true
                end

                # Create our parser object
                parsefiles

                evaluate
            end

            # evaluate our whole tree
            def run(client, facts)
                parsefiles()

                begin
                    if @usenodes
                        unless client
                            raise Puppet::Error,
                                "Cannot evaluate no nodes with a nil client"
                        end

                        # We've already evaluated the AST, in this case
                        @scope.evalnode(client, facts)
                    else
                        scope = Puppet::Parser::Scope.new() # no parent scope
                        scope.interp = self
                        scope.evaluate(@ast, facts)
                    end
                    @ast.evaluate(@scope)
                rescue Puppet::DevError, Puppet::Error, Puppet::ParseError => except
                    #Puppet.err "File %s, line %s: %s" %
                    #    [except.file, except.line, except.message]
                    if Puppet[:debug]
                        puts except.stack
                    end
                    if Puppet[:debug]
                        puts caller
                    end
                    #exit(1)
                    raise
                rescue => except
                    error = Puppet::DevError.new("%s: %s" %
                        [except.class, except.message])
                    error.stack = caller
                    if Puppet[:debug]
                        puts caller
                    end
                    raise error
                end

                # okay, at this point we have a tree of scopes, and we want to
                # unzip along that tree, building our structure of objects
                # to pass to the client
                # this will be heirarchical, and will (at this point) contain
                # only TransObjects and TransSettings
                @topscope.name = "top"
                @topscope.type = "puppet"
                begin
                    topbucket = @topscope.to_trans
                rescue => detail
                    Puppet.warning detail
                    raise
                end

                # add our settings to the front of the array
                # at least, for now
                #@topscope.typesets.each { |setting|
                #    topbucket.unshift setting
                #}

                # guarantee that settings are at the very top
                #topbucket.push settingbucket
                #topbucket.push @scope.to_trans

                #retlist = TransObject.list
                #Puppet.debug "retobject length is %s" % retlist.length
                #TransObject.clear
                return topbucket
            end

            def scope
                return @scope
            end

            private

            # Evaluate the configuration.  If there aren't any nodes defined, then
            # this doesn't actually do anything, because we have to evaluate the
            # entire configuration each time we get a connect.
            def evaluate
                @scope = Puppet::Parser::Scope.new() # no parent scope
                @topscope = @scope
                @scope.interp = self

                if @usenodes
                    Puppet.debug "Nodes defined"
                    @ast.safeevaluate(@scope)
                else
                    Puppet.debug "No nodes defined"
                    return
                end
            end

            def parsefiles
                if defined? @parser
                    unless @parser.reparse?
                        return false
                    end
                end

                unless FileTest.exists?(@file)
                    if @ast
                        Puppet.warning "Manifest %s has disappeared" % @file
                        return
                    else
                        raise Puppet::Error, "Manifest %s must exist" % @file
                    end
                end

                # should i be creating a new parser each time...?
                @parser = Puppet::Parser::Parser.new()
                @parser.file = @file
                @ast = @parser.parse

                evaluate
            end
        end
    end
end

# $Id$
