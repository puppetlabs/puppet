#/usr/bin/ruby

# $Id$
# vim: syntax=ruby

# the AST tree

# the parent class for all of our syntactical objects
module Puppet
    module Parser
        class ASTError < RuntimeError; end
        #---------------------------------------------------------------
        class AST
            attr_accessor :line, :file, :parent

            @@pink = "[0;31m"
            @@green = "[0;32m"
            @@yellow = "[0;33m"
            @@slate = "[0;34m"
            @@reset = "[0m"

            @@indent = " " * 4
            @@indline = @@pink + ("-" * 4) + @@reset
            @@midline = @@slate + ("-" * 4) + @@reset

            @@settypes = Hash.new { |hash,key|
                hash[key] = Hash.new(0)
            }

            def AST.indention
                return @@indent * @@indention
            end

            def AST.midline
                return @@midline
            end

            def evaluate(scope)
                #Puppet.debug("Evaluating ast %s" % @name)
                value = self.collect { |obj|
                    obj.safeevaluate(scope)
                }.reject { |obj|
                    obj.nil?
                }
            end

            def safeevaluate(*args)
                begin
                    self.evaluate(*args)
                rescue Puppet::DevError
                    raise
                rescue => detail
                    if Puppet[:debug]
                        puts caller
                    end
                    error = Puppet::DevError.new(
                        "Child of type %s failed: %s" %
                            [self.class, detail.to_s]
                    )
                    error.stack = caller
                    raise error
                end
            end

            def typewrap(string)
                #return self.class.to_s.sub(/.+::/,'') +
                    #"(" + @@green + string.to_s + @@reset + ")"
                return @@green + string.to_s + @@reset +
                    "(" + self.class.to_s.sub(/.+::/,'') + ")"
            end

            def initialize(args)
                # this has to wait until all of the objects are defined
                unless defined? @@klassorder
                    @@klassorder = [
                        AST::VarDef, AST::TypeDefaults,
                        AST::ObjectDef, AST::StatementArray
                    ]
                end

                args.each { |param,value|
                    method = param.to_s + "="
                    unless self.respond_to?(method)
                        error = Puppet::ParseError.new(
                            "Invalid parameter %s to object class %s" %
                                [method,self.class.to_s]
                        )
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
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
                        error.stack = caller
                        raise error
                    end
                }
            end

            #---------------------------------------------------------------
            # this differentiation is used by the interpreter
            # these objects have children
            class Branch < AST
                include Enumerable
                attr_accessor :pin, :children

                def each
                    @children.each { |child|
                        yield child
                    }
                end

                def evaluate(scope)
                    self.collect { |item|
                        item.safeevaluate(scope)
                    }.reject { |obj|
                        obj.nil
                    }
                end

                def initialize(arghash)
                    super(arghash)

                    unless defined? @children
                        @children = []
                    end

                    #puts "children is '%s'" % [@children]

                    self.each { |child|
                        if child.class == Array
                            error = Puppet::DevError.new(
                                "child for %s(%s) is array" % [self.class,self.parent]
                            )
                            error.stack = caller
                            raise error
                        end
                        unless child.nil?
                            child.parent = self
                        end
                    }
                end

                def tree(indent = 0)
                    return ((@@indline * indent) +
                        self.typewrap(self.pin)) + "\n" + self.collect { |child|
                            child.tree(indent + 1)
                    }.join("\n")
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class ASTArray < AST::Branch
                include Enumerable

                def [](index)
                    @children[index]
                end

                def evaluate(scope)
                    rets = nil
                    if scope.declarative
                        test = [
                            AST::VarDef, AST::TypeDefaults
                        ]

                        # if we're operating declaratively, then we want to get
                        # all of our 'setting' operations done first
                        settors = []
                        others = []
                        @children.each { |child|
                            if test.include?(child.class)
                                settors.push child
                            else
                                others.push child
                            end
                        }
                        rets = [settors,others].flatten.collect { |child|
                            child.safeevaluate(scope)
                        }
                    else
                        rets = @children.collect { |item|
                            item.safeevaluate(scope)
                        }
                    end
                    rets = rets.reject { |obj| obj.nil? }
                end

                def initialize(hash)
                    super(hash)

                    @children.each { |child|
                        unless child.is_a?(AST)
                            Puppet.err("child %s is not an ast" % child)
                            exit
                        end
                    }
                    return self
                end

                def push(*ary)
                    ary.each { |child|
                        #Puppet.debug "adding %s(%s) of type %s to %s" %
                        #    [child, child.object_id, child.class.to_s.sub(/.+::/,''),
                        #    self.object_id]
                        @children.push(child)
                    }

                    return self
                end

                def to_s
                    return "[" + @children.collect { |child|
                        child.to_s
                    }.join(", ") + "]"
                end

                def tree(indent = 0)
                    #puts((AST.indent * indent) + self.pin)
                    self.collect { |child|
                        if child.class == Array
                            Puppet.debug "child is array for %s" % self.class
                        end
                        child.tree(indent)
                    }.join("\n" + (AST.midline * (indent+1)) + "\n")
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class StatementArray < ASTArray
                def evaluate(scope)
                    rets = nil
                    if scope.declarative
                        # if we're operating declaratively, then we want to get
                        # all of our 'setting' operations done first
                        rets = @children.sort { |a,b|
                            [a,b].each { |i|
                                unless  @@klassorder.include?(i.class)
                                    error = Puppet::DevError.new(
                                        "Order not defined for %s" % i.class
                                    )
                                    error.stack = caller
                                    raise error
                                end
                            }
                            @@klassorder.index(a.class) <=> @@klassorder.index(b.class)
                        }.collect { |item|
                            Puppet.debug "Decl evaluating %s" % item.class
                            item.safeevaluate(scope)
                        }.reject { |obj| obj.nil? }
                    else
                        rets = @children.collect { |item|
                            item.safeevaluate(scope)
                        }.reject { |obj| obj.nil? }
                    end

                    return rets
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class ObjectInst < ASTArray; end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # and these ones don't
            class Leaf < AST
                attr_accessor :value, :type

                # this only works if @value has already been evaluated
                # otherwise you get AST objects, which you don't likely want...
                def evaluate(scope)
                    return @value
                end

                def tree(indent = 0)
                    return ((@@indent * indent) + self.typewrap(self.value))
                end

                def to_s
                    return @value
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Boolean < AST::Leaf
                def initialize(hash)
                    super

                    unless @value == 'true' or @value == 'false'
                        error = Puppet::DevError.new(
                            "'%s' is not a boolean" % @value
                        )
                        error.stack = caller
                        raise error
                    end
                    if @value == 'true'
                        @value = true
                    else
                        @value = false
                    end
                end

                def evaluate(scope)
                    return @value
                end

                def to_s
                    return @value
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class String < AST::Leaf
                def evaluate(scope)
                    return scope.strinterp(@value)
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Word < AST::Leaf; end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Default < AST::Leaf; end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Type < AST::Leaf; end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Name < AST::Leaf; end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Variable < Word
                def evaluate(scope)
                    # look up the variable value in the symbol table
                    begin
                        return scope.lookupvar(@value)
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::DevError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class ObjectDef < AST::Branch
                attr_accessor :name, :type
                attr_reader :params

                def []=(index,obj)
                    @params[index] = obj
                end

                def [](index)
                    return @params[index]
                end

                def each
                    #Puppet.debug("each called on %s" % self)
                    [@type,@name,@params].flatten.each { |param|
                        #Puppet.debug("yielding param %s" % param)
                        yield param
                    }
                end

                def evaluate(scope)
                    hash = {}

                    objtype = @type.safeevaluate(scope)
                    objnames = @name.safeevaluate(scope)

                    # first, retrieve the defaults
                    begin
                        defaults = scope.lookupdefaults(objtype)
                    rescue => detail
                        error = Puppet::DevError.new(
                            "Could not lookup defaults for %s: %s" %
                                [objtype, detail.to_s]
                        )
                    end
                    defaults.each { |var,value|
                        Puppet.debug "Found default %s for %s" %
                            [var,objtype]

                        hash[var] = value
                    }

                    # then set all of the specified params
                    @params.each { |param|
                        ary = param.safeevaluate(scope)
                        hash[ary[0]] = ary[1]
                    }

                    # it's easier to always use an array, even for only one name
                    unless objnames.is_a?(Array)
                        objnames = [objnames]
                    end

                    begin
                        object = scope.lookuptype(objtype)
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::ParseError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end

                    # this is where our implicit iteration takes place;
                    # if someone passed an array as the name, then we act
                    # just like the called us many times
                    objnames.collect { |objname|
                        # if the type is not defined in our scope, we assume
                        # that it's a type that the client will understand, so we
                        # just store it in our objectable
                        if object.nil?
                            begin
                                Puppet.debug("Setting object '%s' with arguments %s" %
                                    [objname, hash.inspect])
                                obj = scope.setobject(
                                    objtype,
                                    objname,
                                    hash,
                                    @file,
                                    @line
                                )
                            rescue Puppet::ParseError => except
                                except.line = self.line
                                except.file = self.file
                                raise except
                            rescue => detail
                                error = Puppet::ParseError.new(detail)
                                error.line = self.line
                                error.file = self.file
                                error.stack = caller
                                raise error
                            end
                        else
                            # but things like components create a new type; if we find
                            # one of those, evaluate that with our arguments
                            Puppet.debug("Calling object '%s' with arguments %s" %
                                [object.name, hash.inspect])
                            object.safeevaluate(scope,hash,objtype,objname)
                        end
                    }.reject { |obj| obj.nil? }
                end

                def initialize(hash)
                    super

                    # we don't have to evaluate because we require bare words
                    # for types
                    objtype = @type.value

                    if Puppet[:typecheck]
                        builtin = false
                        begin
                            builtin = Puppet::Type.type(objtype)
                        rescue TypeError
                            # nothing; we've already set builtin to false
                        end
                        if builtin
                            # we're a builtin type
                            #Puppet.debug "%s is a builtin type" % objtype
                            if Puppet[:paramcheck]
                                @params.each { |param|
                                    #p self.name
                                    #p @params
                                    unless param.is_a?(AST::ObjectParam)
                                        raise Puppet::DevError,
                                            "Got something other than param"
                                    end
                                    begin
                                        pname = param.param.value
                                    rescue => detail
                                        raise Puppet::DevError, detail.to_s
                                    end
                                    next if pname == "name" # always allow these
                                    unless builtin.validarg?(pname)
                                        error = Puppet::ParseError.new(
                                            "Invalid parameter '%s' for type '%s'" %
                                                [pname,objtype]
                                        )
                                        error.stack = caller
                                        error.line = self.line
                                        error.file = self.file
                                        raise error
                                    end
                                }
                            end
                        # FIXME this should use scoping rules to find the set type,
                        # not a global list
                        elsif @@settypes.include?(objtype) 
                            # we've defined it locally
                            Puppet.debug "%s is a defined type" % objtype
                            hash = @@settypes[objtype]
                            @params.each { |param|
                                # FIXME we might need to do more here eventually...
                                if Puppet::Type.metaparam?(param.param.value.intern)
                                    next
                                end

                                begin
                                    pname = param.param.value
                                rescue => detail
                                    raise Puppet::DevError, detail.to_s
                                end
                                unless hash.include?(pname)
                                    error = Puppet::ParseError.new(
                                        "Invalid parameter '%s' for type '%s'" %
                                            [pname,objtype]
                                    )
                                    error.stack = caller
                                    error.line = self.line
                                    error.file = self.file
                                    raise error
                                end
                            }
                        else
                            # we don't know anything about it
                            error = Puppet::ParseError.new(
                                "Unknown type '%s'" % objtype
                            )
                            error.line = self.line
                            error.file = self.file
                            error.stack = caller
                            raise error
                        end
                    end
                end

                def params=(params)
                    if params.is_a?(AST::ASTArray)
                        @params = params
                    else
                        @params = AST::ASTArray.new(
                            :line => params.line,
                            :file => params.file,
                            :children => [params]
                        )
                    end
                end

                def tree(indent = 0)
                    return [
                        @type.tree(indent + 1),
                        @name.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin)),
                        @params.collect { |param|
                            begin
                                param.tree(indent + 1)
                            rescue NoMethodError => detail
                                Puppet.err @params.inspect
                                error = Puppet::DevError.new(
                                    "failed to tree a %s" % self.class
                                )
                                error.stack = caller
                                raise error
                            end
                        }.join("\n")
                    ].join("\n")
                end

                def to_s
                    return "%s => { %s }" % [@name,
                        @params.collect { |param|
                            param.to_s
                        }.join("\n")
                    ]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class ObjectRef < AST::Branch
                attr_accessor :name, :type

                def each
                    #Puppet.debug("each called on %s" % self)
                    [@type,@name].flatten.each { |param|
                        #Puppet.debug("yielding param %s" % param)
                        yield param
                    }
                end

                def evaluate(scope)
                    objtype = @type.safeevaluate(scope)
                    objnames = @name.safeevaluate(scope)

                    # it's easier to always use an array, even for only one name
                    unless objnames.is_a?(Array)
                        objnames = [objnames]
                    end

                    begin
                        object = scope.lookuptype(objtype)
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::ParseError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end
                    Puppet.debug "ObjectRef returned type %s" % object

                    # should we implicitly iterate here?
                    # yes, i believe that we essentially have to...
                    objnames.collect { |objname|
                        if object.is_a?(Component)
                            objname = "%s[%s]" % [objtype,objname]
                            objtype = "component"
                        end
                        [objtype,objname]
                    }.reject { |obj| obj.nil? }
                end

                def tree(indent = 0)
                    return [
                        @type.tree(indent + 1),
                        @name.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin))
                    ].join("\n")
                end

                def to_s
                    return "%s[%s]" % [@name,@type]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class ObjectParam < AST::Branch
                attr_accessor :value, :param

                def each
                    [@param,@value].each { |child| yield child }
                end

                def evaluate(scope)
                    param = @param.safeevaluate(scope)
                    value = @value.safeevaluate(scope)
                    return [param, value]
                end

                def tree(indent = 0)
                    return [
                        @param.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin)),
                        @value.tree(indent + 1)
                    ].join("\n")
                end

                def to_s
                    return "%s => %s" % [@param,@value]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class CaseStatement < AST::Branch
                attr_accessor :test, :options, :default

                # 'if' is a bit special, since we don't want to continue
                # evaluating if a test turns up true
                def evaluate(scope)
                    value = @test.safeevaluate(scope)

                    retvalue = nil
                    found = false
                    default = nil
                    @options.each { |option|
                        if option.eachvalue { |opval|
                            if opval == value
                                break true
                            end
                        }
                            # we found a matching option
                            retvalue = option.safeevaluate(scope)
                            break
                        end
                    }

                    unless found
                        if defined? @default
                            retvalue = @default.safeevaluate(scope)
                        else
                            Puppet.debug "No true answers and no default"
                        end
                    end
                    return retvalue
                end

                def initialize(hash)
                    values = {}

                    super
                    # this won't work if we move away from only allowing constants
                    # here
                    # but for now, it's fine and useful
                    @options.each { |option|
                        if option.default?
                            @default = option
                        end
                        option.eachvalue { |val|
                            if values.include?(val)
                                raise Puppet::ParseError,
                                    "Value %s appears twice in case statement" %
                                        val
                            else
                                values[val] = true
                            end
                        }
                    }
                end

                def tree(indent = 0)
                    rettree = [
                        @test.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin)),
                        @options.tree(indent + 1)
                    ]

                    return rettree.flatten.join("\n")
                end

                def each
                    [@test,@options].each { |child| yield child }
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class CaseOpt < AST::Branch
                attr_accessor :value, :statements

                # CaseOpt is a bit special -- we just want the value first,
                # so that CaseStatement can compare, and then it will selectively
                # decide whether to fully evaluate this option

                def default?
                    if defined? @default
                        return @default
                    end

                    if @value.is_a?(AST::ASTArray)
                        @value.each { |subval|
                            if subval.is_a?(AST::Default)
                                @default = true
                                break
                            end
                        }
                    else
                        if @value.is_a?(AST::Default)
                            @default = true
                        end
                    end

                    unless defined? @default
                        @default = false
                    end

                    return @default
                end

                def eachvalue
                    if @value.is_a?(AST::ASTArray)
                        @value.each { |subval|
                            yield subval.value
                        }
                    else
                        yield @value.value
                    end
                end

                def evaluate(scope)
                    return @statements.safeevaluate(scope.newscope)
                end

                def tree(indent = 0)
                    rettree = [
                        @value.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin)),
                        @statements.tree(indent + 1)
                    ]
                    return rettree.flatten.join("\n")
                end

                def each
                    [@value,@statements].each { |child| yield child }
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class Selector < AST::Branch
                attr_accessor :param, :value

                # okay, here's a decision point...
                def evaluate(scope)
                    # retrieve our values and make them a touch easier to manage
                    hash = Hash[*(@value.safeevaluate(scope).flatten)]

                    retvalue = nil

                    paramvalue = @param.safeevaluate(scope)

                    retvalue = hash.detect { |test,value|
                        # FIXME this will return variables named 'default'...
                        if paramvalue == test
                            break value
                        end
                    }
                    if retvalue.nil?
                        if hash.include?("default")
                            return hash["default"]
                        else
                            error = Puppet::ParseError.new(
                                "No value for selector param '%s'" % paramvalue
                            )
                            error.line = self.line
                            error.file = self.file
                            error.stack = self.stack
                            raise error
                        end
                    end

                    return retvalue
                end

                def tree(indent = 0)
                    return [
                        @param.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin)),
                        @value.tree(indent + 1)
                    ].join("\n")
                end

                def each
                    [@param,@value].each { |child| yield child }
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class VarDef < AST::Branch
                attr_accessor :name, :value

                def evaluate(scope)
                    name = @name.safeevaluate(scope)
                    value = @value.safeevaluate(scope)

                    Puppet.debug "setting %s to %s" % [name,value]
                    begin
                        scope.setvar(name,value)
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::ParseError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end
                end

                def each
                    [@name,@value].each { |child| yield child }
                end

                def tree(indent = 0)
                    return [
                        @name.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap(self.pin)),
                        @value.tree(indent + 1)
                    ].join("\n")
                end

                def to_s
                    return "%s => %s" % [@name,@value]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            class TypeDefaults < AST::Branch
                attr_accessor :type, :params

                def each
                    [@type,@params].each { |child| yield child }
                end

                def evaluate(scope)
                    type = @type.safeevaluate(scope)
                    params = @params.safeevaluate(scope)

                    #Puppet.info "Params are %s" % params.inspect
                    #Puppet.debug("evaluating '%s.%s' with values [%s]" %
                    #    [type,name,values])
                    # okay, now i need the interpreter's client object thing...
                    begin
                        scope.setdefaults(type.downcase,params)
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::ParseError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end
                end

                def tree(indent = 0)
                    return [
                        @type.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap(self.pin)),
                        @params.tree(indent + 1)
                    ].join("\n")
                end

                def to_s
                    return "%s { %s }" % [@type,@params]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # these are analogous to defining new object types
            class CompDef < AST::Branch
                attr_accessor :name, :args, :code

                def each
                    [@name,@args,@code].each { |child| yield child }
                end

                def evaluate(scope)
                    name = @name.safeevaluate(scope)
                    args = @args.safeevaluate(scope)

                    #Puppet.debug("defining '%s' with arguments [%s]" %
                    #    [name,args])
                    #p @args
                    #p args
                    # okay, now i need to evaluate all of the statements
                    # within a component and a new lexical scope...

                    begin
                        scope.settype(name,
                            Component.new(
                                :name => name,
                                :args => args,
                                :code => @code
                            )
                        )
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::ParseError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end
                end

                def initialize(hash)
                    super

                    Puppet.debug "Defining type %s" % @name.value

                    # we need to both mark that a given argument is valid,
                    # and we need to also store any provided default arguments
                    hash = @@settypes[@name.value]
                    if @args.is_a?(AST::ASTArray)
                        @args.each { |ary|
                            if ary.is_a?(AST::ASTArray)
                                arg = ary[0]
                                hash[arg.value] += 1
                            else
                                hash[ary.value] += 1
                            end
                        }
                    else
                        #Puppet.warning "got arg %s" % @args.inspect
                        hash[@args.value] += 1
                    end
                end

                def tree(indent = 0)
                    return [
                        @name.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap("define")),
                        @args.tree(indent + 1),
                        @code.tree(indent + 1),
                    ].join("\n")
                end

                def to_s
                    return "define %s(%s) {\n%s }" % [@name, @args, @code]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # these are analogous to defining new object types
            class ClassDef < AST::CompDef
                attr_accessor :parentclass

                def each
                    [@name,@args,@parentclass,@code].each { |child| yield child }
                end

                def evaluate(scope)
                    name = @name.safeevaluate(scope)
                    args = @args.safeevaluate(scope)

                    #Puppet.debug "evaluating parent %s of type %s" %
                    #    [@parent.name, @parent.class]
                    parent = @parentclass.safeevaluate(scope)

                    Puppet.debug("defining hostclass '%s' with arguments [%s]" %
                        [name,args])

                    begin
                        scope.settype(name,
                            HostClass.new(
                                :name => name,
                                :args => args,
                                :parent => parent,
                                :code => @code
                            )
                        )
                    rescue Puppet::ParseError => except
                        except.line = self.line
                        except.file = self.file
                        raise except
                    rescue => detail
                        error = Puppet::ParseError.new(detail)
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end
                end

                def tree(indent = 0)
                    return [
                        @name.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap("class")),
                        @args.tree(indent + 1),
                        @parentclass.tree(indent + 1),
                        @code.tree(indent + 1),
                    ].join("\n")
                end

                def to_s
                    return "class %s(%s) inherits %s {\n%s }" %
                        [@name, @args, @parentclass, @code]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # host definitions are special, because they get called when a host
            # whose name matches connects
            class NodeDef < AST::Branch
                attr_accessor :names, :code

                def each
                    [@names,@code].each { |child| yield child }
                end

                def evaluate(scope)
                    names = @names.safeevaluate(scope)

                    unless names.is_a?(Array)
                        names = [names]
                    end
                    Puppet.debug("defining hosts '%s'" % [names.join(", ")])

                    names.each { |name|
                        begin
                            scope.sethost(name,
                                Host.new(
                                    :name => name,
                                    :code => @code
                                )
                            )
                        rescue Puppet::ParseError => except
                            except.line = self.line
                            except.file = self.file
                            raise except
                        rescue => detail
                            error = Puppet::ParseError.new(detail)
                            error.line = self.line
                            error.file = self.file
                            error.stack = caller
                            raise error
                        end
                    }
                end

                def tree(indent = 0)
                    return [
                        @names.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap("host")),
                        @code.tree(indent + 1),
                    ].join("\n")
                end

                def to_s
                    return "host %s {\n%s }" % [@name, @code]
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # this is not really an AST node; it's just a placeholder
            # for a bunch of AST code to evaluate later
            class Component < AST::Branch
                attr_accessor :name, :args, :code

                def evaluate(scope,hash,objtype,objname)
                    scope = scope.newscope
                    scope.type = objtype
                    scope.name = objname

                    # define all of the arguments in our local scope
                    if self.args
                        Puppet.debug "args are %s" % self.args.inspect
                        self.args.each { |arg, default|
                            unless hash.include?(arg)
                                # FIXME this needs to test for 'defined?'
                                if defined? default
                                    hash[arg] = default
                                else
                                    error = Puppet::ParseError.new(
                                        "Must pass %s to %s of type %s" %
                                            [arg.inspect,name,objtype]
                                    )
                                    error.line = self.line
                                    error.file = self.file
                                    error.stack = caller
                                    raise error
                                end
                            end
                        }
                    end

                    hash["name"] = objname
                    hash.each { |arg,value|
                        begin
                            scope.setvar(arg,hash[arg])
                        rescue Puppet::ParseError => except
                            except.line = self.line
                            except.file = self.file
                            raise except
                        rescue Puppet::ParseError => except
                            except.line = self.line
                            except.file = self.file
                            raise except
                        rescue => except
                            error = Puppet::ParseError.new(except.message)
                            error.line = self.line
                            error.file = self.file
                            error.stack = caller
                            raise error
                        end
                    }

                    # now just evaluate the code with our new bindings
                    self.code.safeevaluate(scope)
                end
            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # this is not really an AST node; it's just a placeholder
            # for a bunch of AST code to evaluate later
            class HostClass < AST::Component
                attr_accessor :parentclass

                def evaluate(scope,hash,objtype,objname)
                    if @parentclass
                        begin
                            parentobj = scope.lookuptype(@parentclass)
                        rescue Puppet::ParseError => except
                            except.line = self.line
                            except.file = self.file
                            raise except
                        rescue => detail
                            error = Puppet::ParseError.new(detail)
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end
                        unless parentobj
                            error = Puppet::ParseError.new( 
                                "Could not find parent '%s' of '%s'" % [@parentclass,@name])
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end
                        parentobj.safeevaluate(scope,hash,objtype,objname)
                    end

                    # just use the Component evaluate method, but change the type
                    # to our own type
                    super(scope,hash,@name,objname)
                end

                def initialize(hash)
                    @parentclass = nil
                    super
                    if self.parent.is_a?(Array)
                        self.parent = nil
                    end
                end

            end
            #---------------------------------------------------------------

            #---------------------------------------------------------------
            # this is not really an AST node; it's just a placeholder
            # for a bunch of AST code to evaluate later
            class Host < AST::Component
                attr_accessor :name, :args, :code, :parentclass

                def evaluate(scope,hash,objtype,objname)
                    if @parentclass
                        begin
                            parentobj = scope.lookuptype(@parentclass)
                        rescue Puppet::ParseError => except
                            except.line = self.line
                            except.file = self.file
                            raise except
                        rescue => detail
                            error = Puppet::ParseError.new(detail)
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end
                        unless parentobj
                            error = Puppet::ParseError.new( 
                                "Could not find parent '%s' of '%s'" % [@parentclass,@name])
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end
                        parentobj.safeevaluate(scope,hash,objtype,objname)
                    end

                    # just use the Component evaluate method, but change the type
                    # to our own type
                    super(scope,hash,@name,objname)
                end
            end
            #---------------------------------------------------------------
        end
    end
end
