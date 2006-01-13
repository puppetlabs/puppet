class Puppet::Parser::AST
    # Evaluate the stored parse tree for a given component.  This will
    # receive the arguments passed to the component and also the type and
    # name of the component.
    class Component < AST::Branch
        class << self
            attr_accessor :name
        end

        # The class name
        @name = :component

        attr_accessor :name, :args, :code, :scope

        def evaluate(scope,hash,objtype,objname)

            scope = scope.newscope

            # The type is the component or class name
            scope.type = objtype

            # The name is the name the user has chosen or that has
            # been dynamically generated.  This is almost never used
            scope.name = objname

            #if self.is_a?(Node)
            #    scope.isnodescope
            #end

            # Additionally, add a tag for whatever kind of class
            # we are
            scope.tag(objtype)

            unless objname =~ /-\d+/ # it was generated
                scope.tag(objname)
            end
            #scope.base = self.class.name


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

            # We return the scope, so that our children can make their scopes
            # under ours.  This allows them to find our definitions.
            return scope
        end
    end

end
