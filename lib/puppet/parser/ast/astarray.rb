require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # The basic container class.  This object behaves almost identically
  # to a normal array except at initialization time.  Note that its name
  # is 'AST::ASTArray', rather than plain 'AST::Array'; I had too many
  # bugs when it was just 'AST::Array', because things like
  # 'object.is_a?(Array)' never behaved as I expected.
  class ASTArray < Branch
    include Enumerable

    # Return a child by index.  Probably never used.
    def [](index)
      @children[index]
    end

    # Evaluate our children.
    def evaluate(scope)
      result = []
      @children.each do |child|
        # Skip things that respond to :instantiate (classes, nodes,
        # and definitions), because they have already been
        # instantiated.
        if !child.respond_to?(:instantiate)
          item = child.safeevaluate(scope)
          if !item.nil?
            # nil values are implicitly removed.
            result.push(item)
          end
        end
      end
      result
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

    def to_s
      "[" + @children.collect { |c| c.to_s }.join(', ') + "]"
    end
  end
end
