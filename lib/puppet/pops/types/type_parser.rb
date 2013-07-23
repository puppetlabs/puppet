# This class provides parsing of Type Specification from a string into the Type
# Model that is produced by the Puppet::Pops::Types::TypeFactory.
#
# The Type Specifications that are parsed are the same as the stringified forms
# of types produced by the Puppet::Pops::Types::TypeCalculator.
#
# @api private
class Puppet::Pops::Types::TypeParser
  TYPES = Puppet::Pops::Types::TypeFactory

  def initialize
    @parser = Puppet::Pops::Parser::Parser.new()
    @type_transformer = Puppet::Pops::Visitor.new(nil, "interpret", 0, 0)
  end

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
      if parameters.size != 2
        raise_invalid_parameters_error("Hash", 2, parameters.size)
      end
      TYPES.hash_of(parameters[1], parameters[0])
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
