require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # An AST object to call a function.
    class Function < AST::Branch

        associates_doc

        attr_accessor :name, :arguments

        @settor = true

        def evaluate(scope)

            # Make sure it's a defined function
            unless @fname
                raise Puppet::ParseError, "Unknown function %s" % @name
            end

            # Now check that it's been used correctly
            case @ftype
            when :rvalue
                unless Puppet::Parser::Functions.rvalue?(@name)
                    raise Puppet::ParseError, "Function '%s' does not return a value" %
                        @name
                end
            when :statement
                if Puppet::Parser::Functions.rvalue?(@name)
                    raise Puppet::ParseError,
                        "Function '%s' must be the value of a statement" %
                        @name
                end
            else
                raise Puppet::DevError, "Invalid function type %s" % @ftype.inspect
            end



            # We don't need to evaluate the name, because it's plaintext
            args = @arguments.safeevaluate(scope)

            return scope.send("function_" + @name, args)
        end

        def initialize(hash)
            @ftype = hash[:ftype] || :rvalue
            hash.delete(:ftype) if hash.include? :ftype

            super(hash)

             @fname = Puppet::Parser::Functions.function(@name)
            # Lastly, check the parity
        end

        def to_s
            args = arguments.is_a?(ASTArray) ? arguments.to_s.gsub(/\[(.*)\]/,'\1') : arguments
            "#{name}(#{args})"
        end
    end
end
