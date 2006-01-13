class Puppet::Parser::AST
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

end
