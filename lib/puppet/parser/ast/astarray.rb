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
            # Make a new array, so we don't have to deal with the details of
            # flattening and such
            items = []

            # First clean out any AST::ASTArrays
            @children.each { |child|
                if child.instance_of?(AST::ASTArray)
                    child.each do |ac|
                        items << ac
                    end
                else
                    items << child
                end
            }

            rets = items.flatten.collect { |child|
                child.safeevaluate(scope)
            }
            return rets.reject { |o| o.nil? }
        end

        def push(*ary)
            ary.each { |child|
                #Puppet.debug "adding %s(%s) of type %s to %s" %
                #    [child, child.object_id, child.class.to_s.sub(/.+::/,''),
                #    self.object_id]
                @children.push(child)
            }

            return self
        end

        def to_s
            "[" + @children.collect { |c| c.to_s }.join(', ') + "]"
        end
    end

    # A simple container class, containing the parameters for an object.
    # Used for abstracting the grammar declarations.  Basically unnecessary
    # except that I kept finding bugs because I had too many arrays that
    # meant completely different things.
    class ResourceInstance < ASTArray; end
end
