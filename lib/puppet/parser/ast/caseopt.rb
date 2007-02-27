require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # Each individual option in a case statement.
    class CaseOpt < AST::Branch
        attr_accessor :value, :statements

        # CaseOpt is a bit special -- we just want the value first,
        # so that CaseStatement can compare, and then it will selectively
        # decide whether to fully evaluate this option

        def each
            [@value,@statements].each { |child| yield child }
        end

        # Are we the default option?
        def default?
            # Cache the @default value.
            if defined? @default
                return @default
            end

            if @value.is_a?(AST::ASTArray)
                @value.each { |subval|
                    if subval.is_a?(AST::Default)
                        @default = true
                        break
                    end
                }
            else
                if @value.is_a?(AST::Default)
                    @default = true
                end
            end

            unless defined? @default
                @default = false
            end

            return @default
        end

        # You can specify a list of values; return each in turn.
        def eachvalue(scope)
            if @value.is_a?(AST::ASTArray)
                @value.each { |subval|
                    yield subval.evaluate(:scope => scope)
                }
            else
                yield @value.evaluate(:scope => scope)
            end
        end

        # Evaluate the actual statements; this only gets called if
        # our option matched.
        def evaluate(hash)
            scope = hash[:scope]
            return @statements.safeevaluate(:scope => scope)
        end

        def tree(indent = 0)
            rettree = [
                @value.tree(indent + 1),
                ((@@indline * indent) + self.typewrap(self.pin)),
                @statements.tree(indent + 1)
            ]
            return rettree.flatten.join("\n")
        end
    end
end

# $Id$
