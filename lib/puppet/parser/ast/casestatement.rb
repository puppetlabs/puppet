require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # The basic logical structure in Puppet.  Supports a list of
    # tests and statement arrays.
    class CaseStatement < AST::Branch
        attr_accessor :test, :options, :default

        associates_doc

        # Short-curcuit evaluation.  Return the value of the statements for
        # the first option that matches.
        def evaluate(scope)
            value = @test.safeevaluate(scope)
            sensitive = Puppet[:casesensitive]
            value = value.downcase if ! sensitive and value.respond_to?(:downcase)

            retvalue = nil
            found = false
            
            # Iterate across the options looking for a match.
            default = nil
            @options.each { |option|
                option.eachvalue(scope) { |opval|
                    opval = opval.downcase if ! sensitive and opval.respond_to?(:downcase)
                    if opval == value
                        found = true
                        break
                    end
                }

                if found
                    # we found a matching option
                    retvalue = option.safeevaluate(scope)
                    break
                end

                if option.default?
                    default = option
                end
            }

            # Unless we found something, look for the default.
            unless found
                if default
                    retvalue = default.safeevaluate(scope)
                else
                    Puppet.debug "No true answers and no default"
                    retvalue = nil
                end
            end
            return retvalue
        end

        def each
            [@test,@options].each { |child| yield child }
        end
    end
end
