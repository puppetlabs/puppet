class Puppet::Parser::AST
    # The parent class of all AST objects that contain other AST objects.
    # Everything but the really simple objects descend from this.  It is
    # important to note that Branch objects contain other AST objects only --
    # if you want to contain values, use a descendent of the AST::Leaf class.
    class Branch < AST
        include Enumerable
        attr_accessor :pin, :children

        # Yield each contained AST node in turn.  Used mostly by 'evaluate'.
        # This definition means that I don't have to override 'evaluate'
        # every time, but each child of Branch will likely need to override
        # this method.
        def each
            @children.each { |child|
                yield child
            }
        end

        # Initialize our object.  Largely relies on the method from the base
        # class, but also does some verification.
        def initialize(arghash)
            super(arghash)

            # Create the hash, if it was not set at initialization time.
            unless defined? @children
                @children = []
            end

            # Verify that we only got valid AST nodes.
            @children.each { |child|
                unless child.is_a?(AST)
                    raise Puppet::DevError,
                        "child %s is a %s instead of ast" % [child, child.class]
                end
            }
        end
    end
end
