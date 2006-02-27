class Puppet::Parser::AST
    # The code associated with a class.  This is different from components
    # in that each class is a singleton -- only one will exist for a given
    # node.
    class HostClass < AST::Component
        @name = :class
        attr_accessor :parentclass

        def evaluate(scope,hash,objtype,objname)
            # Verify that we haven't already been evaluated
            # FIXME The second subclass won't evaluate the parent class
            # code at all, and any overrides will throw an error.
            if scope.lookupclass(self.object_id)
                Puppet.debug "%s class already evaluated" % @name
                return nil
            end

            if tmp = self.evalparent(scope, hash, objname)
                # Override our scope binding with the parent scope
                # binding. This is quite hackish, but I can't think
                # of another way to make sure our scopes end up under
                # our parent scopes.
                scope = tmp
            end

            # just use the Component evaluate method, but change the type
            # to our own type
            retval = super(scope,hash,@name,objname)

            # Set the mark after we evaluate, so we don't record it but
            # then encounter an error
            scope.setclass(self.object_id)
            return retval
        end

        # Evaluate our parent class.  Parent classes are evaluated in the
        # exact same scope as the children.  This is maybe not a good idea
        # but, eh.
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
                        "Class %s has incompatible parent type, %s vs %s" %
                        [@name, parentobj.class, self.class]
                    )
                    error.file = self.file
                    error.line = self.line
                    raise error
                end
                return parentobj.safeevaluate(scope,args,@parentclass,name)
            end
        end

        def initialize(hash)
            @parentclass = nil
            super
        end

    end

end
