require 'puppet/parser/ast/leaf'

class Puppet::Parser::AST
    class ASTHash < Leaf
        include Enumerable

        def [](index)
        end

        # Evaluate our children.
        def evaluate(scope)
            items = {}

            @value.each_pair do |k,v|
                items.merge!({ k => v.safeevaluate(scope) })
            end

            return items
        end

        def merge(hash)
            case hash
            when ASTHash
                @value = @value.merge(hash.value)
            when Hash
                @value = @value.merge(hash)
            end
        end

        def to_s
            "{" + @value.collect { |v| v.collect { |a| a.to_s }.join(' => ') }.join(', ') + "}"
        end
    end
end
