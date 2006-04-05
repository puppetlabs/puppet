class Puppet::Parser::AST
    # The specific code associated with a host.  Nodes are annoyingly unlike
    # other objects.  That's just the way it is, at least for now.
    class Node < AST::HostClass
        @name = :node
        attr_accessor :type, :args, :code, :parentclass

        #def evaluate(scope, facts = {})
        def evaluate(hash)
            scope = hash[:scope]
            facts = hash[:facts] || {}
            #scope.info "name is %s, type is %s" % [self.name, self.type]
            # nodes are never instantiated like a normal object,
            # but we need the type to be the name users would use for
            # instantiation, otherwise tags don't work out
            scope = scope.newscope(
                :type => self.type,
                :keyword => @keyword
            )
            scope.context = self.object_id

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
            @code.safeevaluate(:scope => scope)

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
                node = nil

                # The 'node' method just returns a hash of the node
                # code and name.  It's used here, and in 'evalnode'.
                unless hash = scope.node(@parentclass)
                    raise Puppet::ParseError,
                        "Could not find parent node %s" %
                        @parentclass
                end

                node = hash[:node]
                type = nil
                if type = node.type
                    scope.tag(node.type)
                end

                begin
                    code = node.code
                    code.safeevaluate(:scope => scope)
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
