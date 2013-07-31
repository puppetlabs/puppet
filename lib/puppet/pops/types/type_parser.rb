# This class provides parsing of Type Specification from a string into the Type
# Model that is produced by the Puppet::Pops::Types::TypeFactory.
#
# The Type Specifications that are parsed are the same as the stringified forms
# of types produced by the {Puppet::Pops::Types::TypeCalculator TypeCalculator}.
#
# @api public
class Puppet::Pops::Types::TypeParser
  # @api private
  TYPES = Puppet::Pops::Types::TypeFactory

  # @api public
  def initialize
    @parser = Puppet::Pops::Parser::Parser.new()
    @type_transformer = Puppet::Pops::Visitor.new(nil, "interpret", 0, 0)
  end

  # Produces a *puppet type* based on the given string.
  #
  # @example
  #     parser.parse('Integer')
  #     parser.parse('Array[String]')
  #     parser.parse('Hash[Integer, Array[String]]')
  #
  # @param string [String] a string with the type expressed in stringified form as produced by the 
  #   {Puppet::Pops::Types::TypeCalculator#string TypeCalculator#string} method.
  # @return [Puppet::Pops::Types::PObjectType] a specialization of the PObjectType representing the type.
  #
  # @api public
  #
  def parse(string)
    @string = string
    model = @parser.parse_string(@string)
    if model
      interpret(model.current)
    else
      raise_invalid_type_specification_error
    end
  end

  # @api private
  def interpret(ast)
    @type_transformer.visit_this(self, ast)
  end

  # @api private
  def interpret_Object(anything)
    raise_invalid_type_specification_error
  end

  # @api private
  def interpret_QualifiedReference(name_ast)
    case name_ast.value
    when "integer"
      TYPES.integer
    when "float"
      TYPES.float
    when "string"
      TYPES.string
    when "boolean"
      TYPES.boolean
    when "pattern"
      TYPES.pattern
    when "data"
      TYPES.data
    when "array"
      TYPES.array_of_data
    when "hash"
      TYPES.hash_of_data
    else
      raise_unknown_type_error(name_ast)
    end
  end

  # @api private
  def interpret_AccessExpression(parameterized_ast)
    parameters = parameterized_ast.keys.collect { |param| interpret(param) }
    case parameterized_ast.left_expr.value
    when "array"
      if parameters.size != 1
        raise_invalid_parameters_error("Array", 1, parameters.size)
      end
      TYPES.array_of(parameters[0])
    when "hash"
      if parameters.size == 1
        TYPES.hash_of(parameters[0])
      elsif parameters.size != 2
        raise_invalid_parameters_error("Hash", "1 or 2", parameters.size)
      else
        TYPES.hash_of(parameters[1], parameters[0])
      end
    else
      raise_unknown_type_error(parameterized_ast.left_expr)
    end
  end

  private

  def raise_invalid_type_specification_error
    raise Puppet::ParseError,
      "The expression <#{@string}> is not a valid type specification."
  end

  def raise_invalid_parameters_error(type, required, given)
    raise Puppet::ParseError,
      "Invalid number of type parameters specified: #{type} requires #{required}, #{given} provided"
  end

  def raise_unknown_type_error(ast)
    raise Puppet::ParseError, "Unknown type <#{original_text_of(ast)}>"
  end

  def original_text_of(ast)
    position = Puppet::Pops::Adapters::SourcePosAdapter.adapt(ast)
    position.extract_text_from_string(@string)
  end
end
