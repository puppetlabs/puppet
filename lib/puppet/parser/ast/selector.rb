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
            
            sensitive = Puppet[:casesensitive]
            
            if ! sensitive and paramvalue.respond_to?(:downcase)
                paramvalue = paramvalue.downcase
            end

            default = nil

            unless @values.instance_of? AST::ASTArray or @values.instance_of? Array
                @values = [@values]
            end

            # Then look for a match in the options.
            @values.each { |obj|
                param = obj.param.safeevaluate(:scope => scope)
                if ! sensitive && param.respond_to?(:downcase)
                    param = param.downcase
                end
                if param == paramvalue
                    # we found a matching option
                    retvalue = obj.value.safeevaluate(:scope => scope)
                    found = true
                    break
                elsif obj.param.is_a?(Default)
                    # Store the default, in case it's necessary.
                    default = obj
                end
            }

            # Unless we found something, look for the default.
            unless found
                if default
                    retvalue = default.value.safeevaluate(:scope => scope)
                else
                    self.fail Puppet::ParseError,
                        "No matching value for selector param '%s'" % paramvalue
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

# $Id$
