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
    @undef_t = TYPES.undef
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
  # @return [Puppet::Pops::Types::PAnyType] a specialization of the PAnyType representing the type.
  #
  # @api public
  #
  def parse(string)
    # TODO: This state (@string) can be removed since the parse result of newer future parser
    # contains a Locator in its SourcePosAdapter and the Locator keeps the string.
    # This way, there is no difference between a parsed "string" and something that has been parsed
    # earlier and fed to 'interpret'
    #
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
    result = @type_transformer.visit_this_0(self, ast)
    result = result.body if result.is_a?(Puppet::Pops::Model::Program)
    raise_invalid_type_specification_error unless result.is_a?(Puppet::Pops::Types::PAnyType)
    result
  end

  # @api private
  def interpret_any(ast)
    @type_transformer.visit_this_0(self, ast)
  end

  # @api private
  def interpret_Object(o)
    raise_invalid_type_specification_error
  end

  # @api private
  def interpret_Program(o)
    interpret(o.body)
  end

  # @api private
  def interpret_QualifiedName(o)
    o.value
  end

  # @api private
  def interpret_LiteralString(o)
    o.value
  end

  def interpret_LiteralRegularExpression(o)
    o.value
  end

  # @api private
  def interpret_String(o)
    o
  end

  # @api private
  def interpret_LiteralDefault(o)
    :default
  end

  # @api private
  def interpret_LiteralInteger(o)
    o.value
  end

  # @api private
  def interpret_LiteralFloat(o)
    o.value
  end

  # @api private
  def interpret_LiteralHash(o)
    result = {}
    o.entries.each do |entry|
      result[@type_transformer.visit_this_0(self, entry.key)] = @type_transformer.visit_this_0(self, entry.value)
    end
    result
  end

  # @api private
  def interpret_QualifiedReference(name_ast)
    case name_ast.value
    when "integer"
      TYPES.integer

    when "float"
      TYPES.float

    when "numeric"
        TYPES.numeric

    when "string"
      TYPES.string

    when "enum"
      TYPES.enum

    when "boolean"
      TYPES.boolean

    when "pattern"
      TYPES.pattern

    when "regexp"
      TYPES.regexp

    when "data"
      TYPES.data

    when "array"
      TYPES.array_of_data

    when "hash"
      TYPES.hash_of_data

    when "class"
      TYPES.host_class()

    when "resource"
      TYPES.resource()

    when "collection"
      TYPES.collection()

    when "scalar"
      TYPES.scalar()

    when "catalogentry"
      TYPES.catalog_entry()

    when "undef"
      TYPES.undef()

    when "notundef"
      TYPES.not_undef()

    when "default"
      TYPES.default()

    when "any"
      TYPES.any()

    when "variant"
      TYPES.variant()

    when "optional"
      TYPES.optional()

    when "runtime"
      TYPES.runtime()

    when "type"
      TYPES.type_type()

    when "tuple"
      TYPES.tuple()

    when "struct"
      TYPES.struct()

    when "callable"
      # A generic callable as opposed to one that does not accept arguments
      TYPES.all_callables()

    else
      TYPES.resource(name_ast.value)
    end
  end

  # @api private
  def interpret_AccessExpression(parameterized_ast)
    parameters = parameterized_ast.keys.collect { |param| interpret_any(param) }

    unless parameterized_ast.left_expr.is_a?(Puppet::Pops::Model::QualifiedReference)
      raise_invalid_type_specification_error
    end

    case parameterized_ast.left_expr.value
    when "array"
      case parameters.size
      when 1
      when 2
        size_type =
        if parameters[1].is_a?(Puppet::Pops::Types::PIntegerType)
          parameters[1].copy
        else
          assert_range_parameter(parameters[1])
          TYPES.range(parameters[1], :default)
        end
      when 3
        assert_range_parameter(parameters[1])
        assert_range_parameter(parameters[2])
        size_type = TYPES.range(parameters[1], parameters[2])
      else
        raise_invalid_parameters_error("Array", "1 to 3", parameters.size)
      end
      assert_type(parameters[0])
      t = TYPES.array_of(parameters[0])
      t.size_type = size_type if size_type
      t

    when "hash"
      result = case parameters.size
      when 2
        assert_type(parameters[0])
        assert_type(parameters[1])
        TYPES.hash_of(parameters[1], parameters[0])
      when 3
        size_type =
        if parameters[2].is_a?(Puppet::Pops::Types::PIntegerType)
          parameters[2].copy
        else
          assert_range_parameter(parameters[2])
          TYPES.range(parameters[2], :default)
        end
        assert_type(parameters[0])
        assert_type(parameters[1])
        TYPES.hash_of(parameters[1], parameters[0])
      when 4
        assert_range_parameter(parameters[2])
        assert_range_parameter(parameters[3])
        size_type = TYPES.range(parameters[2], parameters[3])
        assert_type(parameters[0])
        assert_type(parameters[1])
        TYPES.hash_of(parameters[1], parameters[0])
      else
        raise_invalid_parameters_error("Hash", "2 to 4", parameters.size)
      end
      result.size_type = size_type if size_type
      result

    when "collection"
      size_type = case parameters.size
      when 1
        if parameters[0].is_a?(Puppet::Pops::Types::PIntegerType)
          parameters[0].copy
        else
          assert_range_parameter(parameters[0])
          TYPES.range(parameters[0], :default)
        end
      when 2
        assert_range_parameter(parameters[0])
        assert_range_parameter(parameters[1])
        TYPES.range(parameters[0], parameters[1])
      else
        raise_invalid_parameters_error("Collection", "1 to 2", parameters.size)
      end
      result = TYPES.collection
      result.size_type = size_type
      result

    when "class"
      if parameters.size != 1
        raise_invalid_parameters_error("Class", 1, parameters.size)
      end
      TYPES.host_class(parameters[0])

    when "resource"
      if parameters.size == 1
        TYPES.resource(parameters[0])
      elsif parameters.size != 2
        raise_invalid_parameters_error("Resource", "1 or 2", parameters.size)
      else
        TYPES.resource(parameters[0], parameters[1])
      end

    when "regexp"
      # 1 parameter being a string, or regular expression
      raise_invalid_parameters_error("Regexp", "1", parameters.size) unless parameters.size == 1
      TYPES.regexp(parameters[0])

    when "enum"
      # 1..m parameters being strings
      raise_invalid_parameters_error("Enum", "1 or more", parameters.size) unless parameters.size >= 1
      TYPES.enum(*parameters)

    when "pattern"
      # 1..m parameters being strings or regular expressions
      raise_invalid_parameters_error("Pattern", "1 or more", parameters.size) unless parameters.size >= 1
      TYPES.pattern(*parameters)

    when "variant"
      # 1..m parameters being strings or regular expressions
      raise_invalid_parameters_error("Variant", "1 or more", parameters.size) unless parameters.size >= 1
      TYPES.variant(*parameters)

    when "tuple"
      # 1..m parameters being types (last two optionally integer or literal default
      raise_invalid_parameters_error("Tuple", "1 or more", parameters.size) unless parameters.size >= 1
      length = parameters.size
      if TYPES.is_range_parameter?(parameters[-2])
        # min, max specification
        min = parameters[-2]
        min = (min == :default || min == 'default') ? 0 : min
        assert_range_parameter(parameters[-1])
        max = parameters[-1]
        max = max == :default ? nil : max
        parameters = parameters[0, length-2]
      elsif TYPES.is_range_parameter?(parameters[-1])
        min = parameters[-1]
        min = (min == :default || min == 'default') ? 0 : min
        max = nil
        parameters = parameters[0, length-1]
      end
      t = TYPES.tuple(*parameters)
      if min || max
        TYPES.constrain_size(t, min, max)
      end
      t

    when "callable"
      # 1..m parameters being types (last three optionally integer or literal default, and a callable)
      TYPES.callable(*parameters)

    when "struct"
      # 1..m parameters being types (last two optionally integer or literal default
      raise_invalid_parameters_error("Struct", "1", parameters.size) unless parameters.size == 1
      h = parameters[0]
      raise_invalid_type_specification_error unless h.is_a?(Hash)
      TYPES.struct(h)

    when "integer"
      if parameters.size == 1
        case parameters[0]
        when Integer
          TYPES.range(parameters[0], :default)
        when :default
          TYPES.integer # unbound
        end
      elsif parameters.size != 2
        raise_invalid_parameters_error("Integer", "1 or 2", parameters.size)
     else
       TYPES.range(parameters[0] == :default ? nil : parameters[0], parameters[1] == :default ? nil : parameters[1])
     end

    when "float"
      if parameters.size == 1
        case parameters[0]
        when Integer, Float
          TYPES.float_range(parameters[0], :default)
        when :default
          TYPES.float # unbound
        end
      elsif parameters.size != 2
        raise_invalid_parameters_error("Float", "1 or 2", parameters.size)
     else
       TYPES.float_range(parameters[0] == :default ? nil : parameters[0], parameters[1] == :default ? nil : parameters[1])
     end

    when "string"
      size_type =
      case parameters.size
      when 1
        if parameters[0].is_a?(Puppet::Pops::Types::PIntegerType)
          parameters[0].copy
        else
          assert_range_parameter(parameters[0])
          TYPES.range(parameters[0], :default)
        end
      when 2
        assert_range_parameter(parameters[0])
        assert_range_parameter(parameters[1])
        TYPES.range(parameters[0], parameters[1])
      else
        raise_invalid_parameters_error("String", "1 to 2", parameters.size)
      end
      result = TYPES.string
      result.size_type = size_type
      result

    when "optional"
      if parameters.size != 1
        raise_invalid_parameters_error("Optional", 1, parameters.size)
      end
      param = parameters[0]
      assert_type(param) unless param.is_a?(String)
      TYPES.optional(param)

    when "any", "data", "catalogentry", "boolean", "scalar", "undef", "numeric", "default"
      raise_unparameterized_type_error(parameterized_ast.left_expr)

    when "notundef"
      case parameters.size
      when 0
        TYPES.not_undef
      when 1
        param = parameters[0]
        assert_type(param) unless param.is_a?(String)
        TYPES.not_undef(param)
      else
        raise_invalid_parameters_error("NotUndef", "0 to 1", parameters.size)
      end

    when "type"
      if parameters.size != 1
        raise_invalid_parameters_error("Type", 1, parameters.size)
      end
      assert_type(parameters[0])
      TYPES.type_type(parameters[0])

    when "runtime"
      raise_invalid_parameters_error("Runtime", "2", parameters.size) unless parameters.size == 2
      TYPES.runtime(*parameters)

    else
      # It is a resource such a File['/tmp/foo']
      type_name = parameterized_ast.left_expr.value
      if parameters.size != 1
        raise_invalid_parameters_error(type_name.capitalize, 1, parameters.size)
      end
      TYPES.resource(type_name, parameters[0])
    end
  end

  private

  def assert_type(t)
    raise_invalid_type_specification_error unless t.is_a?(Puppet::Pops::Types::PAnyType)
    true
  end

  def assert_range_parameter(t)
    raise_invalid_type_specification_error unless TYPES.is_range_parameter?(t)
  end

  def raise_invalid_type_specification_error
    raise Puppet::ParseError,
      "The expression <#{@string}> is not a valid type specification."
  end

  def raise_invalid_parameters_error(type, required, given)
    raise Puppet::ParseError,
      "Invalid number of type parameters specified: #{type} requires #{required}, #{given} provided"
  end

  def raise_unparameterized_type_error(ast)
    raise Puppet::ParseError, "Not a parameterized type <#{original_text_of(ast)}>"
  end

  def raise_unknown_type_error(ast)
    raise Puppet::ParseError, "Unknown type <#{original_text_of(ast)}>"
  end

  def original_text_of(ast)
    position = Puppet::Pops::Adapters::SourcePosAdapter.adapt(ast)
    position.extract_text()
  end
end
