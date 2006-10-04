require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # A reference to an object.  Only valid as an rvalue.
    class ResourceRef < AST::Branch
        attr_accessor :title, :type

        def each
            [@type,@title].flatten.each { |param|
                #Puppet.debug("yielding param %s" % param)
                yield param
            }
        end

        # Evaluate our object, but just return a simple array of the type
        # and name.
        def evaluate(hash)
            scope = hash[:scope]

            # We want a lower-case type.
            objtype = @type.downcase

            title = @title.safeevaluate(:scope => scope)

            return Puppet::Parser::Resource::Reference.new(
                :type => objtype, :title => title
            )
        end

        def tree(indent = 0)
            return [
                @type.tree(indent + 1),
                @title.tree(indent + 1),
                ((@@indline * indent) + self.typewrap(self.pin))
            ].join("\n")
        end

        def to_s
            return "%s[%s]" % [@type,@title]
        end
    end
end

# $Id$
