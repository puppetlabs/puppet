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
    model = @parser.parse_string(string)
    interpret(model.current.body, context)
  end

  # @api private
  def interpret(ast, context)
    result = @type_transformer.visit_this_1(self, ast, context)
    raise_invalid_type_specification_error(ast) unless result.is_a?(PAnyType)
    result
  end

  # @api private
  def interpret_any(ast, context)
    @type_transformer.visit_this_1(self, ast, context)
  end

  # @api private
  def interpret_Object(o, context)
    raise_invalid_type_specification_error(o)
  end

  # @api private
  def interpret_Program(o, context)
    interpret_any(o.body, context)
  end

  def interpret_LambdaExpression(o, context)
    o
  end

  # @api private
  def interpret_QualifiedName(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralBoolean(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralDefault(o, context)
    :default
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
  def interpret_LiteralInteger(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralList(o, context)
    o.values.map { |value| @type_transformer.visit_this_1(self, value, context) }
  end

  # @api private
  def interpret_LiteralRegularExpression(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralString(o, context)
    o.value
  end

  # @api private
  def interpret_LiteralUndef(o, context)
    nil
  end

  # @api private
  def interpret_String(o, context)
    o
  end

  # @api private
  def interpret_UnaryMinusExpression(o, context)
    -@type_transformer.visit_this_1(self, o.expr, context)
  end

  # @api private
  def self.type_map
    @type_map ||= {
       'integer'       => TypeFactory.integer,
       'float'         => TypeFactory.float,
        'numeric'      => TypeFactory.numeric,
        'iterable'     => TypeFactory.iterable,
        'iterator'     => TypeFactory.iterator,
        'string'       => TypeFactory.string,
        'enum'         => TypeFactory.enum,
        'boolean'      => TypeFactory.boolean,
        'pattern'      => TypeFactory.pattern,
        'regexp'       => TypeFactory.regexp,
        'data'         => TypeFactory.data,
        'array'        => TypeFactory.array_of_data,
        'hash'         => TypeFactory.hash_of_data,
        'class'        => TypeFactory.host_class,
        'resource'     => TypeFactory.resource,
        'collection'   => TypeFactory.collection,
        'scalar'       => TypeFactory.scalar,
        'catalogentry' => TypeFactory.catalog_entry,
        'undef'        => TypeFactory.undef,
        'notundef'     => TypeFactory.not_undef(),
        'default'      => TypeFactory.default(),
        'any'          => TypeFactory.any,
        'variant'      => TypeFactory.variant,
        'optional'     => TypeFactory.optional,
        'runtime'      => TypeFactory.runtime,
        'type'         => TypeFactory.type_type,
        'tuple'        => TypeFactory.tuple,
        'struct'       => TypeFactory.struct,
        'object'       => TypeFactory.object,
        'typealias'    => TypeFactory.type_alias,
        'typereference' => TypeFactory.type_reference,
      # A generic callable as opposed to one that does not accept arguments
        'callable'     => TypeFactory.all_callables,
        'semver'       => TypeFactory.sem_ver,
        'semverrange'  => TypeFactory.sem_ver_range
    }
  end

  # @api private
  def interpret_QualifiedReference(name_ast, context)
    name = name_ast.value
    if found = self.class.type_map[name]
      found
    else
      loader = loader_from_context(name_ast, context)
      unless loader.nil?
        type = loader.load(:type, name)
        type = type.resolve(self, loader) unless type.nil?
      end
      type || TypeFactory.type_reference(name_ast.cased_value)
    end
  end

  # @api private
  def loader_from_context(ast, context)
    if context.nil?
      nil
    elsif context.is_a?(Puppet::Pops::Loader::Loader)
      context
    else
      Puppet::Pops::Adapters::LoaderAdapter.loader_for_model_object(ast, context)
    end
  end

  # @api private
  def interpret_AccessExpression(ast, context)
    parameters = ast.keys.collect { |param| interpret_any(param, context) }

    qref = ast.left_expr
    raise_invalid_type_specification_error(ast) unless qref.is_a?(Model::QualifiedReference)

    type_name = qref.value
    case type_name
    when 'array'
      case parameters.size
      when 1
        type = assert_type(ast, parameters[0])
      when 2
        if parameters[0].is_a?(PAnyType)
          type = parameters[0]
          size_type =
            if parameters[1].is_a?(PIntegerType)
              size_type = parameters[1]
            else
              assert_range_parameter(ast, parameters[1])
              TypeFactory.range(parameters[1], :default)
            end
        else
          type = :default
          assert_range_parameter(ast, parameters[0])
          assert_range_parameter(ast, parameters[1])
          size_type = TypeFactory.range(parameters[0], parameters[1])
        end
      when 3
        type = assert_type(ast, parameters[0])
        assert_range_parameter(ast, parameters[1])
        assert_range_parameter(ast, parameters[2])
        size_type = TypeFactory.range(parameters[1], parameters[2])
      else
        raise_invalid_parameters_error('Array', '1 to 3', parameters.size)
      end
      TypeFactory.array_of(type, size_type)

    when 'hash'
      case parameters.size
      when 2
        if parameters[0].is_a?(PAnyType) && parameters[1].is_a?(PAnyType)
          TypeFactory.hash_of(parameters[1], parameters[0])
        else
          assert_range_parameter(ast, parameters[0])
          assert_range_parameter(ast, parameters[1])
          TypeFactory.hash_of(:default, :default, TypeFactory.range(parameters[0], parameters[1]))
        end
      when 3
        size_type =
          if parameters[2].is_a?(PIntegerType)
            parameters[2]
          else
            assert_range_parameter(ast, parameters[2])
            TypeFactory.range(parameters[2], :default)
          end
        assert_type(ast, parameters[0])
        assert_type(ast, parameters[1])
        TypeFactory.hash_of(parameters[1], parameters[0], size_type)
      when 4
        assert_range_parameter(ast, parameters[2])
        assert_range_parameter(ast, parameters[3])
        assert_type(ast, parameters[0])
        assert_type(ast, parameters[1])
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
            assert_range_parameter(ast, parameters[0])
            TypeFactory.range(parameters[0], :default)
          end
        when 2
          assert_range_parameter(ast, parameters[0])
          assert_range_parameter(ast, parameters[1])
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
      type = parameters[0]
      if type.is_a?(PTypeReferenceType)
        type_str = type.type_string
        param_start = type_str.index('[')
        if param_start.nil?
          type = type_str
        else
          tps = interpret_any(@parser.parse_string(type_str[param_start..-1]).current, context)
          raise_invalid_parameters_error(type.to_s, '1', tps.size) unless tps.size == 1
          type = type_str[0..param_start-1]
          parameters = [type] + tps
        end
      end
      create_resource(type, parameters)

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
        assert_range_parameter(ast, parameters[-1])
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
      raise_invalid_type_specification_error(ast) unless h.is_a?(Hash)
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

    when 'object'
      raise_invalid_parameters_error('Object', 1, parameters.size) unless parameters.size == 1
      TypeFactory.object(parameters[0])

    when 'iterable'
      if parameters.size != 1
        raise_invalid_parameters_error('Iterable', 1, parameters.size)
      end
      assert_type(ast, parameters[0])
      TypeFactory.iterable(parameters[0])

    when 'iterator'
      if parameters.size != 1
        raise_invalid_parameters_error('Iterator', 1, parameters.size)
      end
      assert_type(ast, parameters[0])
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
          assert_range_parameter(ast, parameters[0])
          TypeFactory.range(parameters[0], :default)
        end
      when 2
        assert_range_parameter(ast, parameters[0])
        assert_range_parameter(ast, parameters[1])
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
      assert_type(ast, param) unless param.is_a?(String)
      TypeFactory.optional(param)

    when 'any', 'data', 'catalogentry', 'boolean', 'scalar', 'undef', 'numeric', 'default', 'semverrange'
      raise_unparameterized_type_error(qref)

    when 'notundef'
      case parameters.size
      when 0
        TypeFactory.not_undef
      when 1
        param = parameters[0]
        assert_type(ast, param) unless param.is_a?(String)
        TypeFactory.not_undef(param)
      else
        raise_invalid_parameters_error("NotUndef", "0 to 1", parameters.size)
      end

    when 'type'
      if parameters.size != 1
        raise_invalid_parameters_error('Type', 1, parameters.size)
      end
      assert_type(ast, parameters[0])
      TypeFactory.type_type(parameters[0])

    when 'runtime'
      raise_invalid_parameters_error('Runtime', '2', parameters.size) unless parameters.size == 2
      TypeFactory.runtime(*parameters)

    when 'semver'
      raise_invalid_parameters_error('SemVer', '1 or more', parameters.size) unless parameters.size >= 1
      TypeFactory.sem_ver(*parameters)

    else
      loader = loader_from_context(qref, context)
      type = nil
      unless loader.nil?
        type = loader.load(:type, type_name)
        type = type.resolve(self, loader) unless type.nil?
      end

      if type.nil?
        TypeFactory.type_reference(original_text_of(qref.eContainer))
      elsif type.is_a?(PResourceType)
        raise_invalid_parameters_error(type_name, 1, parameters.size) unless parameters.size == 1
        TypeFactory.resource(type.type_name, parameters[0])
      else
        # Must be a type alias. They can't use parameters (yet)
        raise_unparameterized_type_error(qref)
      end
    end
  end

  private

  def create_resource(name, parameters)
    if parameters.size == 1
      TypeFactory.resource(name)
    elsif parameters.size == 2
      TypeFactory.resource(name, parameters[1])
    else
      raise_invalid_parameters_error('Resource', '1 or 2', parameters.size)
    end
  end

  def assert_type(ast, t)
    raise_invalid_type_specification_error(ast) unless t.is_a?(PAnyType)
    t
  end

  def assert_range_parameter(ast, t)
    raise_invalid_type_specification_error(ast) unless TypeFactory.is_range_parameter?(t)
  end

  def raise_invalid_type_specification_error(ast)
    raise Puppet::ParseError,
      "The expression <#{original_text_of(ast)}> is not a valid type specification."
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
    position.extract_tree_text
  end
end
end
end
