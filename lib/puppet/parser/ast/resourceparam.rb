require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # The AST object for the parameters inside ResourceDefs and Selectors.
    class ResourceParam < AST::Branch
        attr_accessor :value, :param

        def each
            [@param,@value].each { |child| yield child }
        end

        # Return the parameter and the value.
        def evaluate(hash)
            scope = hash[:scope]
            param = @param
            value = @value.safeevaluate(:scope => scope)

            args = {:name => param, :value => value, :source => scope.source}
            [:line, :file].each do |p|
                if v = self.send(p)
                    args[p] = v
                end
            end

            return Puppet::Parser::Resource::Param.new(args)
        end

        def tree(indent = 0)
            return [
                @param.tree(indent + 1),
                ((@@indline * indent) + self.typewrap(self.pin)),
                @value.tree(indent + 1)
            ].join("\n")
        end

        def to_s
            return "%s => %s" % [@param,@value]
        end
    end
end

# $Id$
