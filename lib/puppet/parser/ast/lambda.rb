require 'puppet/parser/ast/block_expression'

class Puppet::Parser::AST
  # A block of statements/expressions with additional parameters
  # Requires scope to contain the values for the defined parameters when evaluated
  # If evaluated without a prepared scope, the lambda will behave like its super class.
  #
  class Lambda < AST::BlockExpression

    # The lambda parameters.
    # These are encoded as an array where each entry is an array of one or two object. The first
    # is the parameter name, and the optional second object is the value expression (that will
    # be evaluated when bound to a scope).
    # The value expression is the default value for the parameter. All default values must be
    # at the end of the parameter list.
    #
    # @return [Array<Array<String,String>>] list of parameter names with optional value expression
    attr_accessor :parameters
    # Evaluates each expression/statement and produce the last expression evaluation result
    # @return [Object] what the last expression evaluated to
    def evaluate(scope)
      if @children.is_a? Puppet::Parser::AST::ASTArray
        result = nil
        @children.each {|expr| result = expr.evaluate(scope) }
        result
      else
        @children.evaluate(scope)
      end
    end

    # Calls the lambda.
    # Assigns argument values in a nested local scope that should be used to evaluate the lambda
    # and then evaluates the lambda.
    # @param scope [Puppet::Scope] the calling scope
    # @return [Object] the result of evaluating the expression(s) in the lambda
    #
    def call(scope, *args)
      raise Puppet::ParseError, "Too many arguments: #{args.size} for #{parameters.size}" unless args.size <= parameters.size

      # associate values with parameters
      merged = parameters.zip(args)
      # calculate missing arguments
      missing = parameters.slice(args.size, parameters.size - args.size).select {|e| e.size == 1}
      unless missing.empty?
        optional = parameters.count { |p| p.size == 2 }
        raise Puppet::ParseError, "Too few arguments; #{args.size} for #{optional > 0 ? ' min ' : ''}#{parameters.size - optional}"
      end

      evaluated = merged.collect do |m|
        # m can be one of
        # m = [["name"], "given"]
        #   | [["name", default_expr], "given"]
        #
        # "given" is always an optional entry. If a parameter was provided then
        # the entry will be in the array, otherwise the m array will be a
        # single element.
        given_argument = m[1]
        argument_name = m[0][0]
        default_expression = m[0][1]

        value = if m.size == 1
          default_expression.safeevaluate(scope)
        else
          given_argument
        end
        [argument_name, value]
      end

      # Store the evaluated name => value associations in a new inner/local/ephemeral scope
      # (This is made complicated due to the fact that the implementation of scope is overloaded with
      # functionality and an inner ephemeral scope must be used (as opposed to just pushing a local scope
      # on a scope "stack").

      # Ensure variable exists with nil value if error occurs. 
      # Some ruby implementations does not like creating variable on return
      result = nil
      begin
        elevel = scope.ephemeral_level
        scope.ephemeral_from(Hash[evaluated], file, line)
        result = safeevaluate(scope)
      ensure
        scope.unset_ephemeral_var(elevel)
      end
      result
    end

    # Validates the lambda.
    # Validation checks if parameters with default values are at the end of the list. (It is illegal
    # to have a parameter with default value followed by one without).
    #
    # @raise [Puppet::ParseError] if a parameter with a default comes before a parameter without default value
    #
    def validate
      params = parameters || []
      defaults = params.drop_while {|p| p.size < 2 }
      trailing = defaults.drop_while {|p| p.size == 2 }
      raise Puppet::ParseError, "Lambda parameters with default values must be placed last" unless trailing.empty?
    end

    # Returns the number of parameters (required and optional)
    # @return [Integer] the total number of accepted parameters
    def parameter_count
      @parameters.size
    end

    # Returns the number of optional parameters.
    # @return [Integer] the number of optional accepted parameters
    def optional_parameter_count
      @parameters.count {|p| p.size == 2 }
    end

    def initialize(options)
      super(options)
      # ensure there is an empty parameters structure if not given by creator
      @parameters = [] unless options[:parameters]
      validate
    end

    def to_s
      result = ["{|"]
      result += @parameters.collect {|p| "#{p[0]}" + (p.size == 2 && p[1]) ? p[1].to_s() : '' }.join(', ')
      result << "| ... }"
      result.join('')
    end

    # marker method checked with respond_to :puppet_lambda
    def puppet_lambda()
      true
    end

    def parameter_names
      @parameters.collect {|p| p[0] }
    end
  end
end
