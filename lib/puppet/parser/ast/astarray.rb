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
        def evaluate(hash)
            scope = hash[:scope]
            rets = nil
            # We basically always operate declaratively, and when we
            # do we need to evaluate the settor-like statements first.  This
            # is basically variable and type-default declarations.
            # This is such a stupid hack.  I've no real idea how to make a
            # "real" declarative language, so I hack it so it looks like
            # one, yay.
            settors = []
            others = []

            # Make a new array, so we don't have to deal with the details of
            # flattening and such
            items = []
            
            # First clean out any AST::ASTArrays
            @children.each { |child|
                if child.instance_of?(AST::ASTArray)
                    child.each do |ac|
                        if ac.class.settor?
                            settors << ac
                        else
                            others << ac
                        end
                    end
                else
                    if child.class.settor?
                        settors << child
                    else
                        others << child
                    end
                end
            }
            rets = [settors, others].flatten.collect { |child|
                child.safeevaluate(:scope => scope)
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

        # Convert to a string.  Only used for printing the parse tree.
        def to_s
            return "[" + @children.collect { |child|
                child.to_s
            }.join(", ") + "]"
        end

        # Print the parse tree.
        def tree(indent = 0)
            #puts((AST.indent * indent) + self.pin)
            self.collect { |child|
                child.tree(indent)
            }.join("\n" + (AST.midline * (indent+1)) + "\n")
        end
    end

    # A simple container class, containing the parameters for an object.
    # Used for abstracting the grammar declarations.  Basically unnecessary
    # except that I kept finding bugs because I had too many arrays that
    # meant completely different things.
    class ResourceInst < ASTArray; end
end

# $Id$
