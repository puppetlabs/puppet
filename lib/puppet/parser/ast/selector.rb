require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # The inline conditional operator.  Unlike CaseStatement, which executes
    # code, we just return a value.
    class Selector < AST::Branch
        attr_accessor :param, :values

        def each
            [@param,@values].each { |child| yield child }
        end

        # Find the value that corresponds with the test.
        def evaluate(hash)
            scope = hash[:scope]
            retvalue = nil
            found = nil

            # Get our parameter.
            paramvalue = @param.safeevaluate(:scope => scope)

            default = nil

            #@values = [@values] unless @values.instance_of? AST::ASTArray
            unless @values.instance_of? AST::ASTArray or @values.instance_of? Array
                @values = [@values]
            end

            # Then look for a match in the options.
            @values.each { |obj|
                param = obj.param.safeevaluate(:scope => scope)
                if param == paramvalue
                    # we found a matching option
                    retvalue = obj.value.safeevaluate(:scope => scope)
                    found = true
                    break
                elsif obj.param.is_a?(Default)
                    default = obj
                end
            }

            # Unless we found something, look for the default.
            unless found
                if default
                    retvalue = default.value.safeevaluate(:scope => scope)
                else
                    self.fail Puppet::ParseError,
                        "No value for selector param '%s'" % paramvalue
                end
            end

            return retvalue
        end

        def tree(indent = 0)
            return [
                @param.tree(indent + 1),
                ((@@indline * indent) + self.typewrap(self.pin)),
                @values.tree(indent + 1)
            ].join("\n")
        end
    end

end
