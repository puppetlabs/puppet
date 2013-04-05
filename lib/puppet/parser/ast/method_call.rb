require 'puppet/parser/ast/branch'
require 'puppet/parser/methods'

class Puppet::Parser::AST
  # An AST object to call a method
  class MethodCall < AST::Branch

    associates_doc

    # An AST that evaluates to the object the method is applied to
    # @return [Puppet::Parser::AST]
    attr_accessor :receiver

    # The name of the method
    # @return [String]
    attr_accessor :name

    # The arguments to evaluate as arguments to the method.
    # @return [Array<Puppet::Parser::AST>]
    attr_accessor :arguments

    # An optional lambda/block that will be yielded to by the called method (if it supports this)
    # @return [Puppet::Parser::AST::Lambda]
    attr_accessor :lambda

    # Evaluates the method call and returns what the called method/function returns.
    # The evaluation evaluates all arguments in the calling scope and then delegates
    # to a "method" instance produced by Puppet::Parser::Methods for this method call.
    # @see Puppet::Parser::Methods
    # @return [Object] what the called method/function returns
    def evaluate(scope)
      # Make sure it's a defined method for the receiver
      r = @receiver.evaluate(scope)
      raise Puppet::ParseError, "No object to apply method #{@name} to" unless r
      m = Puppet::Parser::Methods.find_method(scope, r, @name)
      raise Puppet::ParseError, "Unknown method #{@name} for #{r}" unless m

      # Now check if rvalue is required (in expressions)
      case @ftype
      when :rvalue
        raise Puppet::ParseError, "Method '#{@name}' does not return a value" unless m.is_rvalue?
      when :statement
        # When used as a statement, ignore if it produces a rvalue (it is simply not used)
      else
        raise Puppet::DevError, "Invalid method type #{@ftype.inspect}"
      end

      # Evaluate arguments
      args = @arguments ? @arguments.safeevaluate(scope).map { |x| x == :undef ? '' : x } : []

      # There is no need to evaluate the name, since it is a literal ruby string

      # call the method (it is already bound to the receiver and name)
      m.invoke(scope, args, @lambda)
    end

    def initialize(hash)
      @ftype = hash[:ftype] || :rvalue
      hash.delete(:ftype) if hash.include? :ftype

      super(hash)

      # Lastly, check the parity
    end

    # Sets this method call in statement mode where a produced rvalue is ignored.
    # @return [void]
    def ignore_rvalue
      @ftype = :statement
    end

    def to_s
      args = arguments.is_a?(ASTArray) ? arguments.to_s.gsub(/\[(.*)\]/,'\1') : arguments
      "#{@receiver.to_s}.#{name} (#{args})" + (@lambda ? " #{@lambda.to_s}" : '')
    end
  end
end
