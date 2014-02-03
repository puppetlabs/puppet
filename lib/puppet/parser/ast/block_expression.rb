require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  class BlockExpression < Branch
    include Enumerable

    # Evaluate contained expressions, produce result of the last
    def evaluate(scope)
      result = nil
      @children.each do |child|
        result = child.safeevaluate(scope)
      end
      result
    end

    # Return a child by index.
    def [](index)
      @children[index]
    end

    def push(*ary)
      ary.each { |child|
        #Puppet.debug "adding %s(%s) of type %s to %s" %
        #    [child, child.object_id, child.class.to_s.sub(/.+::/,''),
        #    self.object_id]
        @children.push(child)
      }

      self
    end

    def sequence_with(other)
      Puppet::Parser::AST::BlockExpression.new(:children => self.children + other.children)
    end

    def to_s
      "[" + @children.collect { |c| c.to_s }.join(', ') + "]"
    end
  end
end
