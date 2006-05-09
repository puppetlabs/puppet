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
            args = hash[:arguments]
            # Verify that we haven't already been evaluated
            # FIXME The second subclass won't evaluate the parent class
            # code at all, and any overrides will throw an error.
            if scope.lookupclass(self.object_id)
                Puppet.debug "%s class already evaluated" % @type
                return nil
            end

            # Set the class before we do anything else, so that it's set
            # during the evaluation and can be inspected.
            scope.setclass(self.object_id, @type)

            # Default to creating a new context
            newcontext = true
            transscope = nil
            if parentscope = self.evalparent(
                :scope => scope, :arguments => args, :name => objname
            )
                # Override our scope binding with the parent scope
                # binding. This is quite hackish, but I can't think
                # of another way to make sure our scopes end up under
                # our parent scopes.
                if parentscope.is_a? Puppet::TransBucket
                    raise Puppet::DevError, "Got a bucket instead of a scope"
                end

                scope = parentscope
                transscope = parentscope

                # But don't create a new context if our parent created one
                newcontext = false
            end

            # Just use the Component evaluate method, but change the type
            # to our own type.
            result = super(
                :scope => scope,
                :arguments => args,
                :type => @type,
                :name => objname,               # might be nil
                :newcontext => newcontext,
                :asparent => hash[:asparent]    # might be nil
            )

            # This is important but painfully difficult.  If we're the top-level
            # class, that is, we have no parent classes, then the transscope
            # is our own scope, but if there are parent classes, then the topmost
            # parent's scope is the transscope, since it contains its code and
            # all of the subclass's code.
            transscope ||= result

            if hash[:asparent]
                # If we're a parent class, then return the scope object itself.
                return result
            else
                # But if we're the final subclass, translate the whole scope tree
                # into TransObjects and TransBuckets.
                return transscope.to_trans
            end
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
                # use its own type.  Specify that it's being evaluated as a parent,
                # so that it returns the scope, not a transbucket.
                return parentobj.safeevaluate(
                    :scope => scope,
                    :arguments => args,
                    :name => name,
                    :asparent => true
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
