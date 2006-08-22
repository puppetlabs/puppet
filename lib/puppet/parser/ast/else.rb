class Puppet::Parser::AST
    # A separate ElseIf statement; can function as an 'else' if there's no
    # test.
    class Else < AST::Branch
        attr_accessor :statements

        def each
            yield @statements
        end

        # Evaluate the actual statements; this only gets called if
        # our test was true matched.
        def evaluate(hash)
            scope = hash[:scope]
            return @statements.safeevaluate(:scope => scope)
        end

        def tree(indent = 0)
            rettree = [
                ((@@indline * indent) + self.typewrap(self.pin)),
                @statements.tree(indent + 1)
            ]
            return rettree.flatten.join("\n")
        end
    end
end
