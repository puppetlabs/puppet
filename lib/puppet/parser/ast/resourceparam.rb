require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # The AST object for the parameters inside ResourceDefs and Selectors.
    class ResourceParam < AST::Branch
        attr_accessor :value, :param, :add

        def each
            [@param,@value].each { |child| yield child }
        end

        # Return the parameter and the value.
        def evaluate(hash)
            scope = hash[:scope]

            return Puppet::Parser::Resource::Param.new(
                :name => @param,
                :value => @value.safeevaluate(:scope => scope),
                :source => scope.source, :line => self.line, :file => self.file,
                :add => self.add
            )
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
