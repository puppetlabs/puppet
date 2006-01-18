class Puppet::Parser::AST
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
                #Puppet.debug("defining host '%s' in scope %s" %
                #    [name, scope.object_id])
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

end
