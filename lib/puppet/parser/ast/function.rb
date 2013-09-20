require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # An AST object to call a function.
  class Function < AST::Branch

    associates_doc

    attr_accessor :name, :arguments, :pblock

    def evaluate(scope)
      # Make sure it's a defined function
      raise Puppet::ParseError, "Unknown function #{@name}" unless Puppet::Parser::Functions.function(@name)

      # Now check that it's been used correctly
      case @ftype
      when :rvalue
        raise Puppet::ParseError, "Function '#{@name}' does not return a value" unless Puppet::Parser::Functions.rvalue?(@name)

      when :statement
        # It is harmless to produce an ignored rvalue, the alternative is to mark functions
        # as appropriate for both rvalue and statements
        # Keeping the old behavior when a pblock is not present. This since it is not known
        # if the lambda contains a statement or not (at least not without a costly search).
        # The purpose of the check is to protect a user for producing a meaningless rvalue where the
        # operation has no side effects.
        #
        if !pblock && Puppet::Parser::Functions.rvalue?(@name)
          raise Puppet::ParseError,
            "Function '#{@name}' must be the value of a statement"
        end
      else
        raise Puppet::DevError, "Invalid function type #{@ftype.inspect}"
      end

      # We don't need to evaluate the name, because it's plaintext
      args = @arguments.safeevaluate(scope).map { |x| x == :undef ? '' : x }

      # append a puppet lambda (unevaluated) if it is defined
      args << pblock if pblock

      scope.send("function_#{@name}", args)
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
