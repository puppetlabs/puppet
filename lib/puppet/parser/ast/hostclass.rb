class Puppet::Parser::AST
    # The code associated with a class.  This is different from components
    # in that each class is a singleton -- only one will exist for a given
    # node.
    class HostClass < AST::Component
        @name = :class
        attr_accessor :parentclass

        #def evaluate(scope,hash,objtype,objname)
        def evaluate(hash)
            scope = hash[:scope]
            objtype = hash[:type]
            objname = hash[:name]
            hash = hash[:arguments]
            # Verify that we haven't already been evaluated
            # FIXME The second subclass won't evaluate the parent class
            # code at all, and any overrides will throw an error.
            if scope.lookupclass(self.object_id)
                Puppet.debug "%s class already evaluated" % @type
                return nil
            end

            # Default to creating a new context
            newcontext = true
            if parentscope = self.evalparent(
                :scope => scope, :arguments => hash, :name => objname
            )
                # Override our scope binding with the parent scope
                # binding. This is quite hackish, but I can't think
                # of another way to make sure our scopes end up under
                # our parent scopes.
                scope = parentscope

                # But don't create a new context if our parent created one
                newcontext = false
            end

            # just use the Component evaluate method, but change the type
            # to our own type
            #retval = super(scope,hash,@name,objname)
            retval = super(
                :scope => scope,
                :arguments => hash,
                :type => @type,
                :name => objname,
                :newcontext => newcontext
            )

            # Set the mark after we evaluate, so we don't record it but
            # then encounter an error
            scope.setclass(self.object_id)
            return retval
        end

        # Evaluate our parent class.  Parent classes are evaluated in the
        # exact same scope as the children.  This is maybe not a good idea
        # but, eh.
        #def evalparent(scope, args, name)
        def evalparent(hash)
            scope = hash[:scope]
            args = hash[:arguments]
            name = hash[:name]
            if @parentclass
                #scope.warning "parent class of %s is %s" %
                #    [@type, @parentclass.inspect]
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
                        [@type, parentobj.class, self.class]
                    )
                    error.file = self.file
                    error.line = self.line
                    raise error
                end
                # We don't need to pass the type, because the parent will just
                # use its own type
                return parentobj.safeevaluate(
                    :scope => scope,
                    :arguments => args,
                    :name => name
                )
            else
                return false
            end
        end

        def initialize(hash)
            @parentclass = nil
            super
        end

    end

end
