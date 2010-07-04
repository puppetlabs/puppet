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
            level = scope.ephemeral_level

            value = @test.safeevaluate(scope)

            retvalue = nil
            found = false

            # Iterate across the options looking for a match.
            default = nil
            @options.each do |option|
                option.eachopt do |opt|
                    return option.safeevaluate(scope) if opt.evaluate_match(value, scope, :file => file, :line => line, :sensitive => Puppet[:casesensitive])
                end

                default = option if option.default?
            end

            # Unless we found something, look for the default.
            return default.safeevaluate(scope) if default

            Puppet.debug "No true answers and no default"
            return nil
        ensure
            scope.unset_ephemeral_var(level)
        end

        def each
            [@test,@options].each { |child| yield child }
        end
    end
end
