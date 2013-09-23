require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # Epp is an AST element holding the content of a parsed EPP (Embedded Puppet template). This template consists
  # of regular operations as well as rendering instructions. All rendering instructions produce string output that is
  # collected in a special scope variable (set in an inner local scope). The special variable is an array named `@epp`.
  # When the template has finished evaluating all regular/rendering instructions, the resulting string is produced
  # by joining all strings appended to the `@epp` variable array.
  #
  class Epp < AST::BlockExpression

    # The epp parameters.
    # These are encoded as an array where each entry is an array of one or two object. The first
    # is the parameter name, and the optional second object is the value expression (that will
    # be evaluated when bound to a scope). (Note: this odd construct is the same as for
    # all other types of definitions in puppet (the sane thing to do would be to evaluate the parameter default values
    # when the definition is instantiated, not when it is evaluated).
    # The value expression is the default value for the parameter. Default values does not
    # have to be at the end of the list.
    #
    # @return [Array<Array<String,String>>] list of parameter names with optional value expression
    attr_accessor :parameters

    def initialize(options)
      super(options)
      # ensure there is an empty parameters structure if not given by creator
      @parameters = [] unless options[:parameters]
    end

    def evaluate(scope)
      if @children.is_a? Puppet::Parser::AST::ASTArray
        result = nil
        @children.each {|expr| result = expr.evaluate(scope) }
        result
      else
        @children.evaluate(scope)
      end
    end

    # Calls the epp to produce the resulting text.
    # Accepts an optional hash with named arguments to set as local variables in the local scope used when evaluating
    # the Epp. Excess parameters are allowed, but those that are specified in the template without a default value must be given.
    #
    # Assigns argument values in a nested local scope that should be used to evaluate the lambda
    # and then evaluates the lambda.
    # @param scope [Puppet::Scope] the calling scope
    # @param args [Hash, nil] An optional Hash with template arguments
    # @return [String] the result of evaluating the expression(s) of the epp and joining all rendered strings
    #
    # @raise Puppet::ParseError when a required template argument is missing
    #
    def call(scope, *args)
      raise Puppet::ParseError, "Too many arguments: #{args.size}, max one hash accepted" unless args.size <= 1
      raise Puppet::ParseError, "Argument must be a hash" if args.size == 1 && !args[0].is_a?(Hash)
      arghash = args[0] or {}
      parameters.each {|p|
        unless arghash[p[0]]
          raise Puppet::ParseError, "Missing required argument: #{p[0]}" unless p[1]
          arghash[p[0]] = p[1].safeevaluate(scope) # set default value
        end
      }

      # Create the magic variable "@epp" as an array that all individual renditions go to.
      arghash["@epp"] = []

      # Store the evaluated name => value associations in a new inner/local/ephemeral scope
      # (This is made complicated due to the fact that the implementation of scope is overloaded with
      # functionality and an inner ephemeral scope must be used (as opposed to just pushing a local scope
      # on a scope "stack").
      begin
        elevel = scope.ephemeral_level
        scope.ephemeral_from(arghash, file, line)
        # ignore result
        safeevaluate(scope)
      ensure
        scope.unset_ephemeral_var(elevel)
      end
      # Join all rendered parts and return the resulting string
      arghash["@epp"].join('')
    end

  end

  # Renders a literal string to the special scope array variable `@epp`.
  # @return [void] this function always returns nil
  class RenderString < AST::Leaf
    def evaluate(scope)
      result = @value.dup
      scope["@epp"] << result
      nil
    end

    def to_s
      "%> #{@value} <%"
    end
  end

  # Renders the result of evaluating one expression and transforming the result to a string
  # which is appended to the special scope array variable `@epp`.
  # Note: This class is a leaf since the notion of Leaf vs Branch is not generally honored (look at AST::Minus which
  # is also an unary operator (it is a Branch, but instead of using @children (since it only has one), it defines a
  # value attribute. (Same with AST::Concat and several other classes).
  # (Possibly change this if there is a major cleanup of the entire AST structure).
  # @return [void] this function always returns nil
  #
  class RenderExpression < AST::Leaf
    def evaluate(scope)
      result = @value.safeevaluate(scope)
      result = (result == :undef ? '' : result.to_s)
      scope["@epp"] << result
      nil
    end

    def to_s
      "<%= #{@value.to_s} %>"
    end
  end
end
