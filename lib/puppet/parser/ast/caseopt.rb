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
        def eachvalue
            if @value.is_a?(AST::ASTArray)
                @value.each { |subval|
                    yield subval.value
                }
            else
                yield @value.value
            end
        end

        # Evaluate the actual statements; this only gets called if
        # our option matched.
        def evaluate(scope)
            return @statements.safeevaluate(scope.newscope)
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
