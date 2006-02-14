class Puppet::Parser::AST
    # The specific code associated with a host.  Nodes are annoyingly unlike
    # other objects.  That's just the way it is, at least for now.
    class Node < AST::HostClass
        @name = :node
        attr_accessor :name, :args, :code, :parentclass

        def evaluate(scope, facts = {})
            scope = scope.newscope

            # nodes are never instantiated like a normal object,
            # but we need the type to be the name users would use for
            # instantiation, otherwise tags don't work out

            # The name has already been evaluated, so it's a normal
            # string.
            scope.type = @name
            scope.name = @name
            scope.keyword = @keyword

            # Mark this scope as a nodescope, so that classes will be
            # singletons within it
            scope.isnodescope

            # Now set all of the facts inside this scope
            facts.each { |var, value|
                scope.setvar(var, value)
            }

            if tmp = self.evalparent(scope)
                # Again, override our scope with the parent scope, if
                # there is one.
                scope = tmp
            end

            #scope.tag(@name)

            # We never pass the facts to the parent class, because they've
            # already been defined at this top-level scope.
            #super(scope, facts, @name, @name)

            # And then evaluate our code.
            @code.safeevaluate(scope)

            return scope
        end

        # Evaluate our parent class.
        def evalparent(scope)
            if @parentclass
                Puppet.warning "evaluating parent %s" % @parentclass
                # This is pretty messed up.  I don't know if this will
                # work in the long term, but we need to evaluate the node
                # in our own scope, even though our parent node has
                # a scope associated with it, because otherwise we 1) won't
                # get our facts defined, and 2) we won't actually get the
                # objects returned, based on how nodes work.

                # We also can't just evaluate the node itself, because
                # it would create a node scope within this scope,
                # and that would cause mass havoc.
                node = nil

                # The 'node' method just returns a hash of the node
                # code and name.  It's used here, and in 'evalnode'.
                unless hash = scope.node(@parentclass)
                    raise Puppet::ParseError,
                        "Could not find parent node %s" %
                        @parentclass
                end

                node = hash[:node]
                # Tag the scope with the parent's name/type.
                name = node.name
                #Puppet.info "Tagging with parent node %s" % name
                scope.tag(name)

                begin
                    code = node.code
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

                if node.parentclass
                    node.evalparent(scope)
                end
            end
        end

        def initialize(hash)
            @parentclass = nil
            super

        end
    end
end
