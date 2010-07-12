require 'puppet/parser/ast/leaf'

class Puppet::Parser::AST
  class ASTHash < Leaf
    include Enumerable

    # Evaluate our children.
    def evaluate(scope)
      items = {}

      @value.each_pair do |k,v|
        key = k.respond_to?(:safeevaluate) ? k.safeevaluate(scope) : k
        items.merge!({ key => v.safeevaluate(scope) })
      end

      items
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

    def initialize(args)
      super(args)
      @value ||= {}
    end
  end
end
