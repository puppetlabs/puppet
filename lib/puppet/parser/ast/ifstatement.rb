require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A basic 'if/elsif/else' statement.
    class IfStatement < AST::Branch
        attr_accessor :test, :else, :statements

        def each
            [@test,@else,@statements].each { |child| yield child }
        end

        # Short-curcuit evaluation.  If we're true, evaluate our statements,
        # else if there's an 'else' setting, evaluate it.
        # the first option that matches.
        def evaluate(hash)
            scope = hash[:scope]
            value = @test.safeevaluate(:scope => scope)

            if Puppet::Parser::Scope.true?(value)
                return @statements.safeevaluate(:scope => scope)
            else
                if defined? @else
                    return @else.safeevaluate(:scope => scope)
                else
                    return nil
                end
            end
        end
    end
end
