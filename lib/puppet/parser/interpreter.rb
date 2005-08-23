#!/usr/local/bin/ruby -w

# $Id$

# the interpreter
#
# this builds our virtual pinball machine, into which we'll place our host-specific
# information and out of which we'll receive our host-specific configuration

require 'puppet'
require 'puppet/parser/parser'
require 'puppet/parser/scope'


module Puppet
    module Parser
        #---------------------------------------------------------------
        class Interpreter
            attr_accessor :ast, :topscope
            # just shorten the constant path a bit, using what amounts to an alias
            AST = Puppet::Parser::AST

            #------------------------------------------------------------
            def clear
                TransObject.clear
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            #def callfunc(function,*args)
            #    #Puppet.debug("Calling %s on %s" % [function,@client])
            #    @client.callfunc(function,*args)
            #    #Puppet.debug("Finished %s" % function)
            #end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # create our interpreter
            def initialize(hash)
                unless hash.include?(:ast)
                    raise ArgumentError.new("Must pass tree and client to Interpreter")
                end
                @ast = hash[:ast]
                #@client = hash[:client]

                @scope = Puppet::Parser::Scope.new() # no parent scope
                @topscope = @scope
                @scope.interp = self

                if hash.include?(:facts)
                    facts = hash[:facts]
                    unless facts.is_a?(Hash)
                        raise ArgumentError.new("Facts must be a hash")
                    end

                    facts.each { |fact,value|
                        @scope.setvar(fact,value)
                    }
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # evaluate our whole tree
            def run
                # evaluate returns a value, but at the top level we only
                # care about its side effects
                # i think
                unless @ast.is_a?(AST) or @ast.is_a?(AST::ASTArray)
                    Puppet.err "Received top-level non-ast '%s' of type %s" %
                        [@ast,@ast.class]
                    raise TypeError.new("Received non-ast '%s' of type %s" %
                        [@ast,@ast.class])
                end

                begin
                    @ast.evaluate(@scope)
                rescue Puppet::DevError, Puppet::Error, Puppet::ParseError => except
                    #Puppet.err "File %s, line %s: %s" %
                    #    [except.file, except.line, except.message]
                    if Puppet[:debug]
                        puts except.stack
                    end
                    #exit(1)
                    raise
                rescue => except
                    error = Puppet::DevError.new("%s: %s" %
                        [except.class, except.message])
                    error.stack = caller
                    if Puppet[:debug]
                        puts error.stack
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
            #------------------------------------------------------------

            #------------------------------------------------------------
            def scope
                return @scope
            end
            #------------------------------------------------------------
        end
        #---------------------------------------------------------------
    end
end
