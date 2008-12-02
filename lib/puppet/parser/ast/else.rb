require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A separate ElseIf statement; can function as an 'else' if there's no
    # test.
    class Else < AST::Branch

        associates_doc

        attr_accessor :statements

        def each
            yield @statements
        end

        # Evaluate the actual statements; this only gets called if
        # our test was true matched.
        def evaluate(scope)
            return @statements.safeevaluate(scope)
        end
    end
end
