#!/usr/local/bin/ruby -w

# $Id$

# the interpreter
#
# this builds our virtual pinball machine, into which we'll place our host-specific
# information and out of which we'll receive our host-specific configuration

require 'strscan'
require 'blink'
require 'blink/parser/parser'


module Blink
    class IntepreterError < RuntimeError; end
    module Parser
        #---------------------------------------------------------------
        class Interpreter
            # just shorten the constant path a bit, using what amounts to an alias
            AST = Blink::Parser::Parser::AST

            # make it a class method, since it's not an instance method...
            def Interpreter.descend(root,depthfirst = true,&block)
                #Blink.debug("root is %s of type %s" % [root,root.class])
                root.each_with_index { |thing,index|
                    # this is a problem...
                    # we want to descend into all syntactical objects, but
                    # we don't want to descend into Blink::Objects because
                    # that would mean operating directly on attributes, which
                    # we don't want
                    if depthfirst
                        if thing.is_a?(AST::Branch)
                            Blink.debug("descending thing %s of type %s" %
                                [thing,thing.class])
                            Interpreter.descend(thing,&block)
                        end
                        block.call(thing,index,root)
                    else
                        block.call(thing,index,root)
                        if thing.is_a?(AST::Branch)
                            Blink.debug("descending thing %s of type %s" %
                                [thing,thing.class])
                            Interpreter.descend(thing,&block)
                        end
                    end
                }
            end

            #------------------------------------------------------------
            def askfunc(name,*args)
                if func = Blink::Function[name]
                    # XXX when we're remote, we'll need to do this differently...
                    func.call(*args)
                else
                    raise "Undefined function %s" % name
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # when we have an 'eval' function, we should do that instead
            # for now, we only support variables in strings
            def strinterp(string)
                regex = Regexp.new('\$\{(\w+)\}}')
                while match = regex.match(string) do
                    string.sub!(regex,self.varvalue(match[0]))
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # basically just return the variable value from the symbol
            # table
            def varvalue(variable)
                unless @symtable.include?(variable)
                    raise "Undefined variable %s" % variable
                end

                return @symtable[variable]
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # create our interpreter
            def initialize(tree)
                @tree = tree

                @symtable = Hash.new(nil)
                @factable = Hash.new(nil)
                @objectable = Hash.new { |hash,key|
                    #hash[key] = IObject.new(key)
                    hash[key] = {:name => key}
                }
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # execute all of the passes (probably just one, in the end)
            def run
                regex = %r{^pass}
                self.methods.sort.each { |method,value|
                    if method =~ regex
                        Blink.debug("calling %s" % method)
                        self.send(method)
                    end
                }
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # i don't know how to deal with evaluation here --
            # all Leafs need to be turned into real values, but only in
            # those trees which i know are under 'true' branches
            def pass1_umeverything
                Interpreter.descend(@tree) { |object,index,parent|
                    case object
                    # handle the leaves first
                    when AST::String then
                        # interpolate all variables in the string in-place
                        self.strinterp(object.value)
                    when AST::Word then
                        if parent.is_a?(AST::VarDef) # if we're in an assignment
                            # um, we pretty much don't do anything
                        else
                            # this is where i interpolate the variable, right?
                            # replace the variable AST with a string AST, I guess
                            # unless, of course, the variable points to another
                            # object...
                            # crap, what if it does? 
                        end
                    when AST::VarDef then
                        unless object.name.is_a?(AST::Word)
                            raise InterpreterError.new("invalid variable name")
                        end

                        # this is quite probably more than a simple value...
                        case object.value
                        when AST::String then
                            @symtable[object.name.value] = object.value.value
                        when AST::Word then
                            # just copy whatever's already in the symtable
                            @symtable[object.name.value] =
                                @symtable[object.value.value]
                        else
                            # um, i have no idea what to do in other cases...
                        end
                    when AST::FunctionCall then
                    when AST::ObjectDef then
                        object.params.each { |param|
                        }
                    end
                }
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # this pass creates the actual objects
            # eventually it will probably be one of the last passes, but
            # it's the easiest to create, so...

            # XXX this won't really work for the long term --
            # this will cause each operation on an object to be treated
            # as an independent copy of the object, which will fail
            # purposefully
            def disabled_pass1_mkobjects
                Interpreter.descend(@tree) { |object,index,parent|
                    case object
                    when Blink::Parser::Parser::AST::ObjectDef then # yuk
                        args = {}
                        object.each { |param|
                            # heh, this is weird
                            # the parameter object stores its value in @value
                            # and that's an object, so you have to call .value
                            # again
                            args[param.param] = param.value.value
                        }

                        args[:name] = object.name.value
                        klass = "Blink::Objects::" + object.type.capitalize
                        newobj = eval(klass).new(args)
                        parent[index] = newobj
                    when Blink::Parser::Parser::AST::ObjectParam then
                        # nothing
                    end
                }
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def disabled_pass2_exeobjects
                Blink.debug("tree is %s" % @tree)
                Blink.debug("tree type is %s" % @tree.class)
                Interpreter.descend(@tree) { |object,index,parent|
                    #Blink.debug("object is %s" % object)
                    puts("object is %s" % object)
                    case
                    when object.is_a?(Blink::Objects) then
                        object.evaluate
                    end
                }
            end

            class IObject < Hash
                attr_accessor :name

                @ohash = {}
                @oarray = []

                def initialize(name)
                    if @ohash.include?(name)
                        raise "%s already exists" % name
                    else
                        @ohash[name] = self
                        @oarray.push(self)
                    end
                end
            end
        end
        #---------------------------------------------------------------
    end
end
