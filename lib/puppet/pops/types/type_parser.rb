# This class provides parsing of Type Specification from a string into the Type
# Model that is produced by the TypeFactory.
#
# The Type Specifications that are parsed are the same as the stringified forms
# of types produced by the {TypeCalculator TypeCalculator}.
#
# @api public
module Puppet::Pops
module Types
class TypeParser
  # @api public
  def initialize
    @parser = Parser::Parser.new
    @type_transformer = Visitor.new(nil, 'interpret', 1, 1)
  end

  # Produces a *puppet type* based on the given string.
  #
  # @example
  #     parser.parse('Integer')
  #     parser.parse('Array[String]')
  #     parser.parse('Hash[Integer, Array[String]]')
  #
  # @param string [String] a string with the type expressed in stringified form as produced by the 
  #   types {"#to_s} method.
  # @param context [Puppet::Parser::Scope,Loader::Loader] scope or loader to use when loading type aliases
  # @return [PAnyType] a specialization of the PAnyType representing the type.
  #
  # @api public
  #
  def parse(string, context = nil)
    # TODO: This state (@string) can be removed since the parse result of newer future parser
    # contains a Locator in its SourcePosAdapter and the Locator keeps the string.
    # This way, there is no difference between a parsed "string" and something that has been parsed
    # earlier and fed to 'interpret'
    #
    @string = string
    model = @parser.parse_string(@string)
    if model
      interpret(model.current, context)
    else
      raise_invalid_type_specification_error
    end
  end

  # @api private
  def interpret(ast, context)
    result = @type_transformer.visit_this_1(self, ast, context)
    result = result.body if result.is_a?(Model::Program)
    raise_invalid_type_specification_error unless result.is_a?(PAnyType)
    result
  end

  # @api private
  def interpret_any(ast, context)
    @type_transformer.visit_this_1(self, ast, context)
  end

  # @api private
  def interpret_Object(o, context)
    raise_invalid_type_specification_error
  end

  # @api private
  def interpret_Program(o, context)
    interpret(o.body, context)
  end

  # @api private
  def interpret_QualifiedName(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralString(o, context)
    o.value
  end

  def interpret_LiteralRegularExpression(o, context)
    o.value
  end

  # @api private
  def interpret_String(o, context)
    o
  end

  # @api private
  def interpret_LiteralDefault(o, context)
    :default
  end

  # @api private
  def interpret_LiteralInteger(o, context)
    o.value
  end

  # @api private
  def interpret_UnaryMinusExpression(o, context)
    -@type_transformer.visit_this_1(self, o.expr, context)
  end

  # @api private
  def interpret_LiteralFloat(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralHash(o, context)
    result = {}
    o.entries.each do |entry|
      result[@type_transformer.visit_this_1(self, entry.key, context)] = @type_transformer.visit_this_1(self, entry.value, context)
    end
    result
  end

  # @api private
  def interpret_QualifiedReference(name_ast, context)
    name = name_ast.value
    case name
    when 'integer'
      TypeFactory.integer

    when 'float'
      TypeFactory.float

    when 'numeric'
        TypeFactory.numeric

    when 'iterable'
      TypeFactory.iterable

    when 'iterator'
      TypeFactory.iterator

    when 'string'
      TypeFactory.string

    when 'enum'
      TypeFactory.enum

    when 'boolean'
      TypeFactory.boolean

    when 'pattern'
      TypeFactory.pattern

    when 'regexp'
      TypeFactory.regexp

    when 'data'
      TypeFactory.data

    when 'array'
      TypeFactory.array_of_data

    when 'hash'
      TypeFactory.hash_of_data

    when 'class'
      TypeFactory.host_class

    when 'resource'
      TypeFactory.resource

    when 'collection'
      TypeFactory.collection

    when 'scalar'
      TypeFactory.scalar

    when 'catalogentry'
      TypeFactory.catalog_entry

    when 'undef'
      TypeFactory.undef

    when 'notundef'
      TypeFactory.not_undef()

    when 'default'
      TypeFactory.default()
 
    when 'any'
      TypeFactory.any

    when 'variant'
      TypeFactory.variant

    when 'optional'
      TypeFactory.optional

    when 'runtime'
      TypeFactory.runtime

    when 'type'
      TypeFactory.type_type

    when 'tuple'
      TypeFactory.tuple

    when 'struct'
      TypeFactory.struct

    when 'callable'
      # A generic callable as opposed to one that does not accept arguments
      TypeFactory.all_callables

    else
      if context.nil?
        TypeFactory.type_reference(name.capitalize)
      else
        if context.is_a?(Puppet::Pops::Loader::Loader)
          loader = context
        else
          loader = Puppet::Pops::Adapters::LoaderAdapter.loader_for_model_object(name_ast, context)
        end
        unless loader.nil?
          type = loader.load(:type, name)
          type = type.resolve(self, loader) unless type.nil?
        end
        type || TypeFactory.resource(name)
      end
    end
  end

  # @api private
  def interpret_AccessExpression(parameterized_ast, context)
    parameters = parameterized_ast.keys.collect { |param| interpret_any(param, context) }

    unless parameterized_ast.left_expr.is_a?(Model::QualifiedReference)
      raise_invalid_type_specification_error
    end

    case parameterized_ast.left_expr.value
    when 'array'
      case parameters.size
      when 1
      when 2
        size_type =
          if parameters[1].is_a?(PIntegerType)
            parameters[1]
          else
            assert_range_parameter(parameters[1])
            TypeFactory.range(parameters[1], :default)
          end
      when 3
        assert_range_parameter(parameters[1])
        assert_range_parameter(parameters[2])
        size_type = TypeFactory.range(parameters[1], parameters[2])
      else
        raise_invalid_parameters_error('Array', '1 to 3', parameters.size)
      end
      assert_type(parameters[0])
      TypeFactory.array_of(parameters[0], size_type)

    when 'hash'
      case parameters.size
      when 2
        assert_type(parameters[0])
        assert_type(parameters[1])
        TypeFactory.hash_of(parameters[1], parameters[0])
      when 3
        size_type =
          if parameters[2].is_a?(PIntegerType)
            parameters[2]
          else
            assert_range_parameter(parameters[2])
            TypeFactory.range(parameters[2], :default)
          end
        assert_type(parameters[0])
        assert_type(parameters[1])
        TypeFactory.hash_of(parameters[1], parameters[0], size_type)
      when 4
        assert_range_parameter(parameters[2])
        assert_range_parameter(parameters[3])
        assert_type(parameters[0])
        assert_type(parameters[1])
        TypeFactory.hash_of(parameters[1], parameters[0], TypeFactory.range(parameters[2], parameters[3]))
      else
        raise_invalid_parameters_error('Hash', '2 to 4', parameters.size)
      end

    when 'collection'
      size_type = case parameters.size
        when 1
          if parameters[0].is_a?(PIntegerType)
            parameters[0]
          else
            assert_range_parameter(parameters[0])
            TypeFactory.range(parameters[0], :default)
          end
        when 2
          assert_range_parameter(parameters[0])
          assert_range_parameter(parameters[1])
          TypeFactory.range(parameters[0], parameters[1])
        else
          raise_invalid_parameters_error('Collection', '1 to 2', parameters.size)
        end
      TypeFactory.collection(size_type)

    when 'class'
      if parameters.size != 1
        raise_invalid_parameters_error('Class', 1, parameters.size)
      end
      TypeFactory.host_class(parameters[0])

    when 'resource'
      if parameters.size == 1
        TypeFactory.resource(parameters[0])
      elsif parameters.size != 2
        raise_invalid_parameters_error('Resource', '1 or 2', parameters.size)
      else
        TypeFactory.resource(parameters[0], parameters[1])
      end

    when 'regexp'
      # 1 parameter being a string, or regular expression
      raise_invalid_parameters_error('Regexp', '1', parameters.size) unless parameters.size == 1
      TypeFactory.regexp(parameters[0])

    when 'enum'
      # 1..m parameters being strings
      raise_invalid_parameters_error('Enum', '1 or more', parameters.size) unless parameters.size >= 1
      TypeFactory.enum(*parameters)

    when 'pattern'
      # 1..m parameters being strings or regular expressions
      raise_invalid_parameters_error('Pattern', '1 or more', parameters.size) unless parameters.size >= 1
      TypeFactory.pattern(*parameters)

    when 'variant'
      # 1..m parameters being strings or regular expressions
      raise_invalid_parameters_error('Variant', '1 or more', parameters.size) unless parameters.size >= 1
      TypeFactory.variant(*parameters)

    when 'tuple'
      # 1..m parameters being types (last two optionally integer or literal default
      raise_invalid_parameters_error('Tuple', '1 or more', parameters.size) unless parameters.size >= 1
      length = parameters.size
      size_type = nil
      if TypeFactory.is_range_parameter?(parameters[-2])
        # min, max specification
        min = parameters[-2]
        min = (min == :default || min == 'default') ? 0 : min
        assert_range_parameter(parameters[-1])
        max = parameters[-1]
        max = max == :default ? nil : max
        parameters = parameters[0, length-2]
        size_type = TypeFactory.range(min, max)
      elsif TypeFactory.is_range_parameter?(parameters[-1])
        min = parameters[-1]
        min = (min == :default || min == 'default') ? 0 : min
        max = nil
        parameters = parameters[0, length-1]
        size_type = TypeFactory.range(min, max)
      end
      TypeFactory.tuple(parameters, size_type)

    when 'callable'
      # 1..m parameters being types (last three optionally integer or literal default, and a callable)
      TypeFactory.callable(*parameters)

    when 'struct'
      # 1..m parameters being types (last two optionally integer or literal default
      raise_invalid_parameters_error('Struct', '1', parameters.size) unless parameters.size == 1
      h = parameters[0]
      raise_invalid_type_specification_error unless h.is_a?(Hash)
      TypeFactory.struct(h)

    when 'integer'
      if parameters.size == 1
        case parameters[0]
        when Integer
          TypeFactory.range(parameters[0], :default)
        when :default
          TypeFactory.integer # unbound
        end
      elsif parameters.size != 2
        raise_invalid_parameters_error('Integer', '1 or 2', parameters.size)
     else
       TypeFactory.range(parameters[0] == :default ? nil : parameters[0], parameters[1] == :default ? nil : parameters[1])
     end

    when 'iterable'
      if parameters.size != 1
        raise_invalid_parameters_error('Iterable', 1, parameters.size)
      end
      assert_type(parameters[0])
      TypeFactory.iterable(parameters[0])

    when 'iterator'
      if parameters.size != 1
        raise_invalid_parameters_error('Iterator', 1, parameters.size)
      end
      assert_type(parameters[0])
      TypeFactory.iterator(parameters[0])

    when 'float'
      if parameters.size == 1
        case parameters[0]
        when Integer, Float
          TypeFactory.float_range(parameters[0], :default)
        when :default
          TypeFactory.float # unbound
        end
      elsif parameters.size != 2
        raise_invalid_parameters_error('Float', '1 or 2', parameters.size)
     else
       TypeFactory.float_range(parameters[0] == :default ? nil : parameters[0], parameters[1] == :default ? nil : parameters[1])
     end

    when 'string'
      size_type =
      case parameters.size
      when 1
        if parameters[0].is_a?(PIntegerType)
          parameters[0]
        else
          assert_range_parameter(parameters[0])
          TypeFactory.range(parameters[0], :default)
        end
      when 2
        assert_range_parameter(parameters[0])
        assert_range_parameter(parameters[1])
        TypeFactory.range(parameters[0], parameters[1])
      else
        raise_invalid_parameters_error('String', '1 to 2', parameters.size)
      end
      TypeFactory.string(size_type)

    when 'optional'
      if parameters.size != 1
        raise_invalid_parameters_error('Optional', 1, parameters.size)
      end
      param = parameters[0]
      assert_type(param) unless param.is_a?(String)
      TypeFactory.optional(param)

    when 'any', 'data', 'catalogentry', 'boolean', 'scalar', 'undef', 'numeric', 'default'
      raise_unparameterized_type_error(parameterized_ast.left_expr)

    when 'notundef'
      case parameters.size
      when 0
        TypeFactory.not_undef
      when 1
        param = parameters[0]
        assert_type(param) unless param.is_a?(String)
        TypeFactory.not_undef(param)
      else
        raise_invalid_parameters_error("NotUndef", "0 to 1", parameters.size)
      end

    when 'type'
      if parameters.size != 1
        raise_invalid_parameters_error('Type', 1, parameters.size)
      end
      assert_type(parameters[0])
      TypeFactory.type_type(parameters[0])

    when 'runtime'
      raise_invalid_parameters_error('Runtime', '2', parameters.size) unless parameters.size == 2
      TypeFactory.runtime(*parameters)

    else
      type_name = parameterized_ast.left_expr.value
      if context.nil?
        # Will be impossible to tell from a typed alias (when implemented) so a type reference
        # is returned here for now
        TypeFactory.type_reference(type_name.capitalize, parameters)
      else
        # It is a resource such a File['/tmp/foo']
       if parameters.size != 1
          raise_invalid_parameters_error(type_name.capitalize, 1, parameters.size)
        end
        TypeFactory.resource(type_name, parameters[0])
      end
    end
  end

  private

  def assert_type(t)
    raise_invalid_type_specification_error unless t.is_a?(PAnyType)
    true
  end

  def assert_range_parameter(t)
    raise_invalid_type_specification_error unless TypeFactory.is_range_parameter?(t)
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
    position = Adapters::SourcePosAdapter.adapt(ast)
    position.extract_text
  end
end
end
end
