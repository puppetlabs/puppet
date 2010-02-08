require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A basic 'if/elsif/else' statement.
    class IfStatement < AST::Branch

        associates_doc

        attr_accessor :test, :else, :statements

        def each
            [@test,@else,@statements].each { |child| yield child }
        end

        # Short-curcuit evaluation.  If we're true, evaluate our statements,
        # else if there's an 'else' setting, evaluate it.
        # the first option that matches.
        def evaluate(scope)
            level = scope.ephemeral_level
            value = @test.safeevaluate(scope)

            # let's emulate a new scope for each branches
            begin
                if Puppet::Parser::Scope.true?(value)
                    return @statements.safeevaluate(scope)
                else
                    if defined? @else
                        return @else.safeevaluate(scope)
                    else
                        return nil
                    end
                end
            ensure
                scope.unset_ephemeral_var(level)
            end
        end
    end
end
