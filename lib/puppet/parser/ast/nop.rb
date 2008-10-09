require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # This class is a no-op, it doesn't produce anything
    # when evaluated, hence it's name :-)
    class Nop < AST::Leaf
        def evaluate(scope)
            # nothing to do
        end
    end
end
