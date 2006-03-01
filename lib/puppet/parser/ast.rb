# the parent class for all of our syntactical objects

require 'puppet'

module Puppet
    module Parser
        # The base class for all of the objects that make up the parse trees.
        # Handles things like file name, line #, and also does the initialization
        # for all of the parameters of all of the child objects.
        class AST
            # Do this so I don't have to type the full path in all of the subclasses
            AST = Puppet::Parser::AST

            Puppet.setdefaults("ast",
                :typecheck => [true, "Whether to validate types during parsing."],
                :paramcheck => [true, "Whether to validate parameters during parsing."]
            )
            attr_accessor :line, :file, :parent, :scope

            # Just used for 'tree', which is only used in debugging.
            @@pink = "[0;31m"
            @@green = "[0;32m"
            @@yellow = "[0;33m"
            @@slate = "[0;34m"
            @@reset = "[0m"

            # Just used for 'tree', which is only used in debugging.
            @@indent = " " * 4
            @@indline = @@pink + ("-" * 4) + @@reset
            @@midline = @@slate + ("-" * 4) + @@reset

            @@settypes = {}

            # Just used for 'tree', which is only used in debugging.
            def AST.indention
                return @@indent * @@indention
            end

            # Just used for 'tree', which is only used in debugging.
            def AST.midline
                return @@midline
            end

            # Evaluate the current object.  Basically just iterates across all
            # of the contained children and evaluates them in turn, returning a
            # list of all of the collected values, rejecting nil values
            def evaluate(args)
                #Puppet.debug("Evaluating ast %s" % @name)
                value = self.collect { |obj|
                    obj.safeevaluate(args)
                }.reject { |obj|
                    obj.nil?
                }
            end

            # The version of the evaluate method that should be called, because it
            # correctly handles errors.  It is critical to use this method because
            # it can enable you to catch the error where it happens, rather than
            # much higher up the stack.
            def safeevaluate(*args)
                begin
                    self.evaluate(*args)
                rescue Puppet::DevError => except
                    except.line ||= @line
                    except.file ||= @file
                    raise
                rescue Puppet::ParseError => except
                    except.line ||= @line
                    except.file ||= @file
                    raise
                rescue => detail
                    if Puppet[:debug]
                        puts detail.backtrace
                    end
                    error = Puppet::DevError.new(
                        "Child of type %s failed with error %s: %s" %
                            [self.class, detail.class, detail.to_s]
                    )
                    error.line ||= @line
                    error.file ||= @file
                    raise error
                end
            end

            # Again, just used for printing out the parse tree.
            def typewrap(string)
                #return self.class.to_s.sub(/.+::/,'') +
                    #"(" + @@green + string.to_s + @@reset + ")"
                return @@green + string.to_s + @@reset +
                    "(" + self.class.to_s.sub(/.+::/,'') + ")"
            end

            # Initialize the object.  Requires a hash as the argument, and
            # takes each of the parameters of the hash and calls the settor
            # method for them.  This is probably pretty inefficient and should
            # likely be changed at some point.
            def initialize(args)
                @file = nil
                @line = nil
                args.each { |param,value|
                    method = param.to_s + "="
                    unless self.respond_to?(method)
                        error = Puppet::ParseError.new(
                            "Invalid parameter %s to object class %s" %
                                [param,self.class.to_s]
                        )
                        error.line = self.line
                        error.file = self.file
                        raise error
                    end

                    begin
                        #Puppet.debug("sending %s to %s" % [method, self.class])
                        self.send(method,value)
                    rescue => detail
                        error = Puppet::DevError.new(
                            "Could not set parameter %s on class %s: %s" %
                                [method,self.class.to_s,detail]
                        )
                        error.line ||= self.line
                        error.file ||= self.file
                        raise error
                    end
                }
            end
            #---------------------------------------------------------------
        end
    end
end

require 'puppet/parser/ast/astarray'
require 'puppet/parser/ast/branch'
require 'puppet/parser/ast/caseopt'
require 'puppet/parser/ast/casestatement'
require 'puppet/parser/ast/classdef'
require 'puppet/parser/ast/compdef'
require 'puppet/parser/ast/component'
require 'puppet/parser/ast/hostclass'
require 'puppet/parser/ast/leaf'
require 'puppet/parser/ast/node'
require 'puppet/parser/ast/nodedef'
require 'puppet/parser/ast/objectdef'
require 'puppet/parser/ast/objectparam'
require 'puppet/parser/ast/objectref'
require 'puppet/parser/ast/selector'
require 'puppet/parser/ast/typedefaults'
require 'puppet/parser/ast/vardef'

# $Id$
