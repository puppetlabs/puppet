class Puppet::Parser::AST
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
            unless type.validattr?(pname)
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

end
