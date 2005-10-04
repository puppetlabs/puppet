# the parent class for all of our syntactical objects

require 'puppet'

module Puppet
    module Parser

        # The base class for all of the objects that make up the parse trees.
        # Handles things like file name, line #, and also does the initialization
        # for all of the parameters of all of the child objects.
        class AST
            Puppet.setdefault(:typecheck, true)
            Puppet.setdefault(:paramcheck, true)
            attr_accessor :line, :file, :parent

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
            def evaluate(scope)
                #Puppet.debug("Evaluating ast %s" % @name)
                value = self.collect { |obj|
                    obj.safeevaluate(scope)
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
                rescue Puppet::DevError
                    raise
                rescue Puppet::ParseError
                    raise
                rescue => detail
                    if Puppet[:debug]
                        puts caller
                    end
                    error = Puppet::DevError.new(
                        "Child of type %s failed with error %s: %s" %
                            [self.class, detail.class, detail.to_s]
                    )
                    error.stack = caller
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

            # Initialize the object.  Requires a hash as the argument, and takes
            # each of the parameters of the hash and calls the settor method for
            # them.  This is probably pretty inefficient and should likely be changed
            # at some point.
            def initialize(args)
                @file = nil
                @line = nil
                args.each { |param,value|
                    method = param.to_s + "="
                    unless self.respond_to?(method)
                        error = Puppet::DevError.new(
                            "Invalid parameter %s to object class %s" %
                                [param,self.class.to_s]
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

            # The parent class of all AST objects that contain other AST objects.
            # Everything but the really simple objects descend from this.  It is
            # important to note that Branch objects contain other AST objects only --
            # if you want to contain values, use a descendent of the AST::Leaf class.
            class Branch < AST
                include Enumerable
                attr_accessor :pin, :children

                # Yield each contained AST node in turn.  Used mostly by 'evaluate'.
                # This definition means that I don't have to override 'evaluate'
                # every time, but each child of Branch will likely need to override
                # this method.
                def each
                    @children.each { |child|
                        yield child
                    }
                end

                # Initialize our object.  Largely relies on the method from the base
                # class, but also does some verification.
                def initialize(arghash)
                    super(arghash)

                    # Create the hash, if it was not set at initialization time.
                    unless defined? @children
                        @children = []
                    end

                    # Verify that we only got valid AST nodes.
                    @children.each { |child|
                        unless child.is_a?(AST)
                            raise Puppet::DevError,
                                "child %s is not an ast" % child
                        end
                    }
                end

                # Pretty-print the parse tree.
                def tree(indent = 0)
                    return ((@@indline * indent) +
                        self.typewrap(self.pin)) + "\n" + self.collect { |child|
                            child.tree(indent + 1)
                    }.join("\n")
                end
            end

            # The basic container class.  This object behaves almost identically
            # to a normal array except at initialization time.  Note that its name
            # is 'AST::ASTArray', rather than plain 'AST::Array'; I had too many
            # bugs when it was just 'AST::Array', because things like
            # 'object.is_a?(Array)' never behaved as I expected.
            class ASTArray < AST::Branch
                include Enumerable

                # Return a child by index.  Probably never used.
                def [](index)
                    @children[index]
                end

                # Evaluate our children.
                def evaluate(scope)
                    rets = nil
                    # We basically always operate declaratively, and when we
                    # do we need to evaluate the settor-like statements first.  This
                    # is basically variable and type-default declarations.
                    if scope.declarative?
                        test = [
                            AST::VarDef, AST::TypeDefaults
                        ]

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
                        # If we're not declarative, just do everything in order.
                        rets = @children.collect { |item|
                            item.safeevaluate(scope)
                        }
                    end
                    rets = rets.reject { |obj| obj.nil? }
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

                # Convert to a string.  Only used for printing the parse tree.
                def to_s
                    return "[" + @children.collect { |child|
                        child.to_s
                    }.join(", ") + "]"
                end

                # Print the parse tree.
                def tree(indent = 0)
                    #puts((AST.indent * indent) + self.pin)
                    self.collect { |child|
                        child.tree(indent)
                    }.join("\n" + (AST.midline * (indent+1)) + "\n")
                end
            end

            # A simple container class, containing the parameters for an object.
            # Used for abstracting the grammar declarations.  Basically unnecessary
            # except that I kept finding bugs because I had too many arrays that
            # meant completely different things.
            class ObjectInst < ASTArray; end

            # Another simple container class to make sure we can correctly arrayfy
            # things.
            class CompArgument < ASTArray; end

            # The base class for all of the leaves of the parse trees.  These
            # basically just have types and values.  Both of these parameters
            # are simple values, not AST objects.
            class Leaf < AST
                attr_accessor :value, :type

                # Return our value.
                def evaluate(scope)
                    return @value
                end

                # Print the value in parse tree context.
                def tree(indent = 0)
                    return ((@@indent * indent) + self.typewrap(self.value))
                end

                def to_s
                    return @value
                end
            end

            # The boolean class.  True or false.  Converts the string it receives
            # to a Ruby boolean.
            class Boolean < AST::Leaf

                # Use the parent method, but then convert to a real boolean.
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
            end

            # The base string class.
            class String < AST::Leaf
                # Interpolate the string looking for variables, and then return
                # the result.
                def evaluate(scope)
                    return scope.strinterp(@value)
                end
            end
            #---------------------------------------------------------------

            # The 'default' option on case statements and selectors.
            class Default < AST::Leaf; end

            # Capitalized words; used mostly for type-defaults, but also
            # get returned by the lexer any other time an unquoted capitalized
            # word is found.
            class Type < AST::Leaf; end

            # Lower-case words.
            class Name < AST::Leaf; end

            # A simple variable.  This object is only used during interpolation;
            # the VarDef class is used for assignment.
            class Variable < Name
                # Looks up the value of the object in the scope tree (does
                # not include syntactical constructs, like '$' and '{}').
                def evaluate(scope)
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

            # Any normal puppet object declaration.  Can result in a class or a 
            # component, in addition to builtin types.
            class ObjectDef < AST::Branch
                attr_accessor :name, :type
                attr_reader :params

                # probably not used at all
                def []=(index,obj)
                    @params[index] = obj
                end

                # probably not used at all
                def [](index)
                    return @params[index]
                end

                # Auto-generate a name
                def autoname(type, object)
                    case object
                    when Puppet::Type:
                        raise Puppet::Error,
                            "Built-in types must be provided with a name"
                    when HostClass:
                        return type
                    else
                        Puppet.info "Autogenerating name for object of type %s" %
                            type
                        return [type, "-", self.object_id].join("")
                    end
                end

                # Iterate across all of our children.
                def each
                    [@type,@name,@params].flatten.each { |param|
                        #Puppet.debug("yielding param %s" % param)
                        yield param
                    }
                end

                # Does not actually return an object; instead sets an object
                # in the current scope.
                def evaluate(scope)
                    hash = {}

                    # Get our type and name.
                    objtype = @type.safeevaluate(scope)

                    # If the type was a variable, we wouldn't have typechecked yet.
                    # Do it now, if so.
                    unless @checked
                        self.typecheck(objtype)
                    end

                    # See if our object was defined
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

                    unless object
                        # If not, verify that it's a builtin type
                        begin
                            object = Puppet::Type.type(objtype)
                        rescue TypeError
                            # otherwise, the user specified an invalid type
                            error = Puppet::ParseError.new(
                                "Invalid type %s" % objtype
                            )
                            error.line = @line
                            error.file = @file
                            raise error
                        end
                    end

                    # Autogenerate the name if one was not passed.
                    if defined? @name
                        objnames = @name.safeevaluate(scope)
                    else
                        objnames = self.autoname(objtype, object)
                    end

                    # it's easier to always use an array, even for only one name
                    unless objnames.is_a?(Array)
                        objnames = [objnames]
                    end

                    # Retrieve the defaults for our type
                    hash = getdefaults(objtype, scope)

                    # then set all of the specified params
                    @params.each { |param|
                        ary = param.safeevaluate(scope)
                        hash[ary[0]] = ary[1]
                    }

                    # this is where our implicit iteration takes place;
                    # if someone passed an array as the name, then we act
                    # just like the called us many times
                    objnames.collect { |objname|
                        # If the object is a class, that means it's a builtin type
                        if object.is_a?(Class)
                            begin
                                Puppet.debug(
                                    ("Setting object '%s' " +
                                    "in scope %s " +
                                    "with arguments %s") %
                                    [objname, scope.object_id, hash.inspect]
                                )
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

                # Retrieve the defaults for our type
                def getdefaults(objtype, scope)
                    # first, retrieve the defaults
                    begin
                        defaults = scope.lookupdefaults(objtype)
                        if defaults.length > 0
                            Puppet.debug "Got defaults for %s: %s" %
                                [objtype,defaults.inspect]
                        end
                    rescue => detail
                        raise Puppet::DevError, 
                            "Could not lookup defaults for %s: %s" %
                                [objtype, detail.to_s]
                    end

                    hash = {}
                    # Add any found defaults to our argument list
                    defaults.each { |var,value|
                        Puppet.debug "Found default %s for %s" %
                            [var,objtype]

                        hash[var] = value
                    }

                    return hash
                end

                # Create our ObjectDef.  Handles type checking for us.
                def initialize(hash)
                    @checked = false
                    super

                    if @type.is_a?(Variable)
                        Puppet.debug "Delaying typecheck"
                        return
                    else
                        self.typecheck(@type.value)

                        objtype = @type.value
                    end

                end

                # Verify that all passed parameters are valid
                def paramcheck(builtin, objtype)
                    # This defaults to true
                    unless Puppet[:paramcheck]
                        return
                    end

                    @params.each { |param|
                        if builtin
                            self.parambuiltincheck(builtin, param)
                        else
                            self.paramdefinedcheck(objtype, param)
                        end
                    }
                end

                def parambuiltincheck(type, param)
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
                    unless type.validarg?(pname)
                        error = Puppet::ParseError.new(
                            "Invalid parameter '%s' for type '%s'" %
                                [pname,type.name]
                        )
                        error.stack = caller
                        error.line = self.line
                        error.file = self.file
                        raise error
                    end
                end

                def paramdefinedcheck(objtype, param)
                    # FIXME we might need to do more here eventually...
                    if Puppet::Type.metaparam?(param.param.value.intern)
                        next
                    end

                    begin
                        pname = param.param.value
                    rescue => detail
                        raise Puppet::DevError, detail.to_s
                    end

                    unless @@settypes[objtype].validarg?(pname)
                        error = Puppet::ParseError.new(
                            "Invalid parameter '%s' for type '%s'" %
                                [pname,objtype]
                        )
                        error.stack = caller
                        error.line = self.line
                        error.file = self.file
                        raise error
                    end
                end

                # Set the parameters for our object.
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

                # Print this object out.
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

                # Verify that the type is valid.  This throws an error if there's
                # a problem, so the return value doesn't matter
                def typecheck(objtype)
                    # This will basically always be on, but I wanted to make it at
                    # least simple to turn off if it came to that
                    unless Puppet[:typecheck]
                        return
                    end

                    builtin = false
                    begin
                        builtin = Puppet::Type.type(objtype)
                    rescue TypeError
                        # nothing; we've already set builtin to false
                    end

                    unless builtin or @@settypes.include?(objtype) 
                        error = Puppet::ParseError.new(
                            "Unknown type '%s'" % objtype
                        )
                        error.line = self.line
                        error.file = self.file
                        error.stack = caller
                        raise error
                    end

                    unless builtin
                        Puppet.debug "%s is a defined type" % objtype
                    end

                    self.paramcheck(builtin, objtype)

                    @checked = true
                end

                def to_s
                    return "%s => { %s }" % [@name,
                        @params.collect { |param|
                            param.to_s
                        }.join("\n")
                    ]
                end
            end

            # A reference to an object.  Only valid as an rvalue.
            class ObjectRef < AST::Branch
                attr_accessor :name, :type

                def each
                    [@type,@name].flatten.each { |param|
                        #Puppet.debug("yielding param %s" % param)
                        yield param
                    }
                end

                # Evaluate our object, but just return a simple array of the type
                # and name.
                def evaluate(scope)
                    objtype = @type.safeevaluate(scope)
                    objnames = @name.safeevaluate(scope)

                    # it's easier to always use an array, even for only one name
                    unless objnames.is_a?(Array)
                        objnames = [objnames]
                    end

                    # Verify we can find the object.
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
                        if object.is_a?(AST::Component)
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

            # The AST object for the parameters inside ObjectDefs and Selectors.
            class ObjectParam < AST::Branch
                attr_accessor :value, :param

                def each
                    [@param,@value].each { |child| yield child }
                end

                # Return the parameter and the value.
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

            # The basic logical structure in Puppet.  Supports a list of
            # tests and statement arrays.
            class CaseStatement < AST::Branch
                attr_accessor :test, :options, :default

                # Short-curcuit evaluation.  Return the value of the statements for
                # the first option that matches.
                def evaluate(scope)
                    value = @test.safeevaluate(scope)

                    retvalue = nil
                    found = false
                    
                    # Iterate across the options looking for a match.
                    @options.each { |option|
                        if option.eachvalue { |opval| break true if opval == value }
                            # we found a matching option
                            retvalue = option.safeevaluate(scope)
                            found = true
                            break
                        end
                    }

                    # Unless we found something, look for the default.
                    unless found
                        if defined? @default
                            retvalue = @default.safeevaluate(scope)
                        else
                            Puppet.debug "No true answers and no default"
                        end
                    end
                    return retvalue
                end

                # Do some input validation on our options.
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

            # Each individual option in a case statement.
            class CaseOpt < AST::Branch
                attr_accessor :value, :statements

                # CaseOpt is a bit special -- we just want the value first,
                # so that CaseStatement can compare, and then it will selectively
                # decide whether to fully evaluate this option

                def each
                    [@value,@statements].each { |child| yield child }
                end

                # Are we the default option?
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

                # You can specify a list of values; return each in turn.
                def eachvalue
                    if @value.is_a?(AST::ASTArray)
                        @value.each { |subval|
                            yield subval.value
                        }
                    else
                        yield @value.value
                    end
                end

                # Evaluate the actual statements; this only gets called if
                # our option matched.
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
            end

            # The inline conditional operator.  Unlike CaseStatement, which executes
            # code, we just return a value.
            class Selector < AST::Branch
                attr_accessor :param, :values

                def each
                    [@param,@values].each { |child| yield child }
                end

                # Find the value that corresponds with the test.
                def evaluate(scope)
                    retvalue = nil
                    found = nil

                    # Get our parameter.
                    paramvalue = @param.safeevaluate(scope)

                    default = nil

                    # Then look for a match in the options.
                    @values.each { |obj|
                        param = obj.param.safeevaluate(scope)
                        if param == paramvalue
                            # we found a matching option
                            retvalue = obj.value.safeevaluate(scope)
                            found = true
                            break
                        elsif obj.param.is_a?(Default)
                            default = obj
                        end
                    }

                    # Unless we found something, look for the default.
                    unless found
                        if default
                            retvalue = default.value.safeevaluate(scope)
                        else
                            error = Puppet::ParseError.new(
                                "No value for selector param '%s'" % paramvalue
                            )
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end
                    end

                    return retvalue
                end

                def tree(indent = 0)
                    return [
                        @param.tree(indent + 1),
                        ((@@indline * indent) + self.typewrap(self.pin)),
                        @values.tree(indent + 1)
                    ].join("\n")
                end
            end

            # Define a variable.  Stores the value in the current scope.
            class VarDef < AST::Branch
                attr_accessor :name, :value

                # Look up our name and value, and store them appropriately.  The
                # lexer strips off the syntax stuff like '$'.
                def evaluate(scope)
                    name = @name.safeevaluate(scope)
                    value = @value.safeevaluate(scope)

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

            # A statement syntactically similar to an ObjectDef, but uses a
            # capitalized object type and cannot have a name.  
            class TypeDefaults < AST::Branch
                attr_accessor :type, :params

                def each
                    [@type,@params].each { |child| yield child }
                end

                # As opposed to ObjectDef, this stores each default for the given
                # object type.
                def evaluate(scope)
                    type = @type.safeevaluate(scope)
                    params = @params.safeevaluate(scope)

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

            # Define a new component.  This basically just stores the
            # associated parse tree by name in our current scope.  Note that
            # there is currently a mismatch in how we look up components -- it
            # usually uses scopes, but sometimes uses '@@settypes'.
            # FIXME This class should verify that each of its direct children
            # has an abstractable name -- i.e., if a file does not include a
            # variable in its name, then the user is essentially guaranteed to
            # encounter an error if the component is instantiated more than
            # once.
            class CompDef < AST::Branch
                attr_accessor :name, :args, :code

                def each
                    [@name,@args,@code].each { |child| yield child }
                end

                # Store the parse tree.
                def evaluate(scope)
                    name = @name.safeevaluate(scope)
                    args = @args.safeevaluate(scope)

                    begin
                        scope.settype(name,
                            AST::Component.new(
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
                    @parentclass = nil
                    super

                    Puppet.debug "Defining type %s" % @name.value

                    # we need to both mark that a given argument is valid,
                    # and we need to also store any provided default arguments
                    # FIXME This creates a global list of types and their
                    # acceptable arguments.  This should really be scoped
                    # instead.
                    @@settypes[@name.value] = self
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

                # Check whether a given argument is valid.  Searches up through
                # any parent classes that might exist.
                def validarg?(param)
                    found = false
                    if @args.is_a?(AST::ASTArray)
                        found = @args.detect { |arg|
                            if arg.is_a?(AST::ASTArray)
                                arg[0].value == param
                            else
                                arg.value == param
                            end
                        }
                    else
                        found = @args.value == param
                        #Puppet.warning "got arg %s" % @args.inspect
                        #hash[@args.value] += 1
                    end

                    if found
                        return true
                    # a nil parentclass is an empty astarray
                    # stupid but true
                    elsif @parentclass
                        parent = @@settypes[@parentclass.value]
                        if parent and parent != []
                            return parent.validarg?(param)
                        else
                            raise Puppet::Error, "Could not find parent class %s" %
                                @parentclass.value
                        end
                    else
                        return false
                    end

                end
            end

            # Define a new class.  Syntactically similar to component definitions,
            # but classes are always singletons -- only one can exist on a given
            # host.
            class ClassDef < AST::CompDef
                attr_accessor :parentclass

                def each
                    if @parentclass
                        #[@name,@args,@parentclass,@code].each { |child| yield child }
                        [@name,@parentclass,@code].each { |child| yield child }
                    else
                        #[@name,@args,@code].each { |child| yield child }
                        [@name,@code].each { |child| yield child }
                    end
                end

                # Store our parse tree according to name.
                def evaluate(scope)
                    name = @name.safeevaluate(scope)
                    #args = @args.safeevaluate(scope)

                        #:args => args,
                    arghash = {
                        :name => name,
                        :code => @code
                    }

                    if @parentclass
                        arghash[:parentclass] = @parentclass.safeevaluate(scope)
                    end

                    #Puppet.debug("defining hostclass '%s' with arguments [%s]" %
                    #    [name,args])

                    begin
                        scope.settype(name,
                            HostClass.new(arghash)
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
                    @parentclass = nil
                    super
                end

                def tree(indent = 0)
                        #@args.tree(indent + 1),
                    return [
                        @name.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap("class")),
                        @parentclass ? @parentclass.tree(indent + 1) : "",
                        @code.tree(indent + 1),
                    ].join("\n")
                end

                def to_s
                    return "class %s(%s) inherits %s {\n%s }" %
                        [@name, @parentclass, @code]
                        #[@name, @args, @parentclass, @code]
                end
            end

            # Define a node.  The node definition stores a parse tree for each
            # specified node, and this parse tree is only ever looked up when
            # a client connects.
            class NodeDef < AST::Branch
                attr_accessor :names, :code, :parentclass

                def each
                    [@names,@code].each { |child| yield child }
                end

                # Do implicit iteration over each of the names passed.
                def evaluate(scope)
                    names = @names.safeevaluate(scope)

                    unless names.is_a?(Array)
                        names = [names]
                    end
                    
                    names.each { |name|
                        Puppet.debug("defining host '%s'" % name)
                        arghash = {
                            :name => name,
                            :code => @code
                        }

                        if @parentclass
                            arghash[:parentclass] = @parentclass.safeevaluate(scope)
                        end

                        begin
                            scope.setnode(name,
                                Node.new(arghash)
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

                def initialize(hash)
                    @parentclass = nil
                    super
                end

                def tree(indent = 0)
                    return [
                        @names.tree(indent + 1),
                        ((@@indline * 4 * indent) + self.typewrap("node")),
                        @code.tree(indent + 1),
                    ].join("\n")
                end

                def to_s
                    return "node %s {\n%s }" % [@name, @code]
                end
            end

            # Evaluate the stored parse tree for a given component.  This will
            # receive the arguments passed to the component and also the type and
            # name of the component.
            class Component < AST::Branch
                class << self
                    attr_accessor :name
                end

                # The class name
                @name = :component

                attr_accessor :name, :args, :code

                def evaluate(scope,hash,objtype,objname)
                    scope = scope.newscope

                    # The type is the component or class name
                    scope.type = objtype

                    # The name is the name the user has chosen or that has
                    # been dynamically generated.  This is almost never used
                    scope.name = objname

                    # Additionally, add a tag for whatever kind of class
                    # we are
                    scope.base = self.class.name


                    # define all of the arguments in our local scope
                    if self.args

                        # Verify that all required arguments are either present or
                        # have been provided with defaults.
                        # FIXME This should probably also require each parent
                        # class's arguments...
                        self.args.each { |arg, default|
                            unless hash.include?(arg)
                                if defined? default and ! default.nil?
                                    hash[arg] = default
                                    Puppet.debug "Got default %s for %s in %s" %
                                        [default.inspect, arg.inspect, objname.inspect]
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

                    # Set each of the provided arguments as variables in the
                    # component's scope.
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

                    # Now just evaluate the code with our new bindings.
                    self.code.safeevaluate(scope)
                end
            end

            # The code associated with a class.  This is different from components
            # in that each class is a singleton -- only one will exist for a given
            # node.
            class HostClass < AST::Component
                @name = :class
                attr_accessor :parentclass

                def evaluate(scope,hash,objtype,objname)
                    if scope.lookupclass(@name)
                        Puppet.debug "%s class already evaluated" % @name
                        return nil
                    end

                    self.evalparent(scope, hash, objname)

                    # just use the Component evaluate method, but change the type
                    # to our own type
                    retval = super(scope,hash,@name,objname)

                    # Set the mark after we evaluate, so we don't record it but
                    # then encounter an error
                    scope.setclass(@name)
                    return retval
                end

                # Evaluate our parent class.  
                def evalparent(scope, args, name)
                    if @parentclass
                        parentobj = nil

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
                                "Could not find parent '%s' of '%s'" %
                                    [@parentclass,@name])
                            error.line = self.line
                            error.file = self.file
                            raise error
                        end

                        # Verify that the parent and child are of the same type
                        unless parentobj.class == self.class
                            error = Puppet::ParseError.new(
                                "Class %s has incompatible parent type" %
                                [@name]
                            )
                            error.file = self.file
                            error.line = self.line
                            raise error
                        end
                        parentobj.safeevaluate(scope,args,@parentclass,name)
                    end
                end

                def initialize(hash)
                    @parentclass = nil
                    super
                end

            end

            # The specific code associated with a host.  
            class Node < AST::Component
                @name = :node
                attr_accessor :name, :args, :code, :parentclass

                def evaluate(scope, facts = {})
                    scope = scope.newscope
                    scope.type = "node"
                    scope.name = @name

                    # Mark this scope as a nodescope, so that classes will be
                    # singletons within it
                    scope.nodescope = true

                    # Now set all of the facts inside this scope
                    facts.each { |var, value|
                        scope.setvar(var, value)
                    }

                    self.evalparent(scope)

                    # And then evaluate our code.
                    @code.safeevaluate(scope)

                    return scope
                end

                # Evaluate our parent class.
                def evalparent(scope)
                    if @parentclass
                        # This is pretty messed up.  I don't know if this will
                        # work in the long term, but we need to evaluate the node
                        # in our own scope, even though our parent node has
                        # a scope associated with it, because otherwise we 1) won't
                        # get our facts defined, and 2) we won't actually get the
                        # objects returned, based on how nodes work.

                        # We also can't just evaluate the node itself, because
                        # it would create a node scope within this scope,
                        # and that would cause mass havoc.
                        hash = nil
                        unless hash = scope.node(@parentclass)
                            raise Puppet::ParseError,
                                "Could not find parent node %s" %
                                @parentclass
                        end

                        begin
                            code = hash[:node].code
                            code.safeevaluate(scope)
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
                    end
                end

                def initialize(hash)
                    @parentclass = nil
                    super

                end
            end
            #---------------------------------------------------------------
        end
    end
end

# $Id$
