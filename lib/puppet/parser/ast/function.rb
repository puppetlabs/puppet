require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # An AST object to call a function.
    class Function < AST::Branch

        associates_doc

        attr_accessor :name, :arguments

        @settor = true

        def evaluate(scope)

            # Make sure it's a defined function
            unless Puppet::Parser::Functions.function(@name)
                raise Puppet::ParseError, "Unknown function #{@name}"
            end

            # Now check that it's been used correctly
            case @ftype
            when :rvalue
                unless Puppet::Parser::Functions.rvalue?(@name)
                    raise Puppet::ParseError, "Function '#{@name}' does not return a value"
                end
            when :statement
                if Puppet::Parser::Functions.rvalue?(@name)
                    raise Puppet::ParseError,
                        "Function '#{@name}' must be the value of a statement"
                end
            else
                raise Puppet::DevError, "Invalid function type #{@ftype.inspect}"
            end

            # We don't need to evaluate the name, because it's plaintext
            args = @arguments.safeevaluate(scope)

            return scope.send("function_#{@name}", args)
        end

        def initialize(hash)
            @ftype = hash[:ftype] || :rvalue
            hash.delete(:ftype) if hash.include? :ftype

            super(hash)

            # Lastly, check the parity
        end

        def to_s
            args = arguments.is_a?(ASTArray) ? arguments.to_s.gsub(/\[(.*)\]/,'\1') : arguments
            "#{name}(#{args})"
        end
    end
end
