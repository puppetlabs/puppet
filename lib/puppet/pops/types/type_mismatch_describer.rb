module Puppet::Pops
module Types
  EMPTY_ARRAY = [].freeze

  class TypePathElement
    attr_reader :key

    def initialize(key)
      @key = key
    end

    def hash
      key.hash
    end

    def ==(o)
      self.class == o.class && key == o.key
    end

    alias :eql? :==
  end

  class MemberPathElement < TypePathElement
    def to_s
      "struct member #{key}"
    end
  end

  class MemberKeyPathElement < TypePathElement
    def to_s
      "struct member key #{key}"
    end
  end

  class ParameterPathElement < TypePathElement
    def to_s
      "parameter '#{key}'"
    end
  end

  class BlockPathElement < ParameterPathElement
    def initialize(name = 'block')
      super(name)
    end

    def to_s
      key
    end
  end

  class ArrayPathElement < TypePathElement
    def to_s
      "index #{key}"
    end
  end

  class VariantPathElement < TypePathElement
    def to_s
      "variant #{key}"
    end
  end

  class SignaturePathElement < VariantPathElement
    def to_s
      "#{key+1}."
    end
  end

  class Mismatch
    attr_reader :path

    def initialize(path)
      @path = path || EMPTY_ARRAY
    end

    def canonical_path
      @canonical_path ||= @path.reject { |e| e.is_a?(VariantPathElement) }
    end

    def message(variant, position)
      "#{variant}unknown mismatch#{position}"
    end

    def merge(path, o)
      self.class.new(path)
    end

    def ==(o)
      self.class == o.class && canonical_path == o.canonical_path
    end

    alias :eql? :==

    def hash
      canonical_path.hash
    end

    def chop_path(element_index)
      return self if element_index >= @path.size
      chopped_path = @path.clone
      chopped_path.delete_at(element_index)
      copy = self.clone
      copy.instance_variable_set(:@path, chopped_path)
      copy
    end

    def path_string
      @path.join(' ')
    end

    def to_s
      p = @path
      variant = ''
      position = ''
      unless p.empty?
        f = p.first
        if f.is_a?(SignaturePathElement)
          variant = " #{f}"
          p = p.drop(1)
        end
        position = " #{p.join(' ')}" unless p.empty?
      end
      message(variant, position)
    end
  end

  # @abstract
  class KeyMismatch < Mismatch
    attr_reader :key

    def initialize(path, key)
      super(path)
      @key = key
    end

    def ==(o)
      super.==(o) && key == o.key
    end

    def hash
      super.hash * 31 + key.hash
    end
  end

  class MissingKey < KeyMismatch
    def message(variant, position)
      "#{variant}#{position} expects a value for key '#{key}'"
    end
  end

  class MissingParameter < KeyMismatch
    def message(variant, position)
      "#{variant}#{position} expects a value for parameter '#{key}'"
    end
  end

  class ExtraneousKey < KeyMismatch
    def message(variant, position)
      "#{variant}#{position} has no '#{@key}' key"
    end
  end

  class InvalidParameter < ExtraneousKey
    def message(variant, position)
      "#{variant}#{position} has no parameter named '#{@key}'"
    end
  end

  class UnexpectedBlock < Mismatch
    def message(variant, position)
      "#{variant}#{position} does not expect a block"
    end
  end

  class MissingRequiredBlock < Mismatch
    def message(variant, position)
      "#{variant}#{position} expects a block"
    end
  end

  class ExpectedActualMismatch < Mismatch
    attr_reader :expected, :actual

    def initialize(path, expected, actual)
      super(path)
      @expected = expected
      @actual = actual
    end

    def ==(o)
      super.==(o) && expected == o.expected && actual == o.actual
    end

    def hash
      hash = super.hash
      hash = hash * 31 + expected.hash
      hash * 31 + actual.hash
    end
  end

  class TypeMismatch < ExpectedActualMismatch
    include LabelProvider

    # @return A new instance with the least restrictive respective boundaries
    def merge(path, o)
      self.class.new(path, [expected, o.expected].flatten.uniq, actual)
    end

    def message(variant, position)
      e = expected
      a = actual
      multi = false
      if e.is_a?(Array)
        # Use simple names when classes differ, or in other words, only include details
        # when the classes are equal.
        #
        if a.is_a?(PTypeAliasType) || e.find { |t| t.class == a.class || t.is_a?(PTypeAliasType) }
          e = e.map { |t| t.to_s }
          a = a.to_s
        else
          sns = e.map { |t| t.simple_name }.uniq
          e = e.map { |t| s = t.simple_name; sns.count {|x| x == s } == 1 ? s : t.to_s }.uniq
          a = a.simple_name
        end
        case e.size
        when 1
          e = e[0]
        when 2
          e = "#{e[0]} or #{e[1]}"
          multi = true
        else
          e = "#{e[0..e.size-2].join(', ')}, or #{e[e.size-1]}"
          multi = true
        end
      else
        if e.class != a.class && !(e.is_a?(PTypeAliasType) || a.is_a?(PTypeAliasType))
          e = e.simple_name
          a = a.simple_name
        else
          e = e.to_s
          a = a.to_s
        end
      end
      multi ? "#{variant}#{position} expects a value of type #{e}, got #{label(a)}" :  "#{variant}#{position} expects #{a_an(e)} value, got #{label(a)}"
    end

    def label(o)
      o.to_s
    end
  end

  class PatternMismatch < TypeMismatch
    def message(variant, position)
      "#{variant}#{position} expects a match for #{expected}, got #{actual_string}"
    end

    def actual_string
      a = actual
      a.is_a?(PStringType) && a.values.size == 1 ? "'#{a.values[0]}'" : a.simple_name
    end
  end

  class SizeMismatch < ExpectedActualMismatch
    def from
      @expected.from || 0
    end

    def to
      @expected.to || Float::INFINITY
    end

    # @return A new instance with the least restrictive respective boundaries
    def merge(path, o)
      range = PIntegerType.new(from < o.from ? from : o.from, to > o.to ? to : o.to)
      self.class.new(path, range, @actual)
    end

    def message(variant, position)
      "#{variant}#{position} expects size to be #{range_to_s(expected, '0')}, got #{range_to_s(actual, '0')}"
    end

    def range_to_s(range, zero_string)
      min = range.from || 0
      max = range.to || Float::INFINITY
      if min == max
        min == 0 ? zero_string : min.to_s
      elsif min == 0
        max == Float::INFINITY ? 'unlimited' : "at most #{max}"
      elsif max == Float::INFINITY
        "at least #{min}"
      else
        "between #{min} and #{max}"
      end
    end
  end

  class CountMismatch < SizeMismatch
    def initialize(path, expected, actual)
      super(path, expected, actual)
    end

    def message(variant, position)
      min = expected.from || 0
      max = expected.to || Float::INFINITY
      suffix = min == 1 && (max == 1 || max == Float::INFINITY) || min == 0 && max == 1 ? '' : 's'
      "#{variant}#{position} expects #{range_to_s(expected, 'no')} argument#{suffix}, got #{range_to_s(actual, 'none')}"
    end
  end

  class TypeMismatchDescriber
    def self.validate_parameters(subject, params_struct, given_hash, missing_ok = false)
      singleton.validate_parameters(subject, params_struct, given_hash, missing_ok)
    end

    def self.validate_default_parameter(subject, param_name, param_type, value)
      singleton.validate_default_parameter(subject, param_name, param_type, value)
    end

    def self.describe_signatures(closure, signatures, args_tuple)
      singleton.describe_signatures(closure, signatures, args_tuple)
    end

    def self.singleton
      @singleton ||= new
    end

    # Validates that all entries in the give_hash exists in the given param_struct, that their type conforms
    # with the corresponding param_struct element and that all required values are provided.
    #
    # @param subject [String] string to be prepended to the exception message
    # @param params_struct [PStructType] Struct to use for validation
    # @param given_hash [Hash<String,Object>] the parameters to validate
    # @param missing_ok [Boolean] Do not generate errors on missing parameters
    #
    def validate_parameters(subject, params_struct, given_hash, missing_ok = false)
      errors = describe_struct_signature(params_struct, given_hash, missing_ok).flatten
      case errors.size
      when 0
      when 1
        raise Puppet::ParseError.new("#{subject}:#{errors[0]}")
      else
        raise Puppet::ParseError.new("#{subject}:\n #{errors.join("\n ")}")
      end
    end

    # @param subject [String] string to be prepended to the exception message
    # @param param_name [String] parameter name
    # @param param_type [PAnyType] parameter type
    # @param value [Object] value to be validated against the given type
    #
    def validate_default_parameter(subject, param_name, param_type, value)
      unless param_type.instance?(value)
        errors = describe(param_type, TypeCalculator.singleton.infer_set(value).generalize, [ParameterPathElement.new(param_name)])
        case errors.size
        when 0
        when 1
          raise Puppet::ParseError.new("#{subject}:#{errors[0]}")
        else
          raise Puppet::ParseError.new("#{subject}:\n #{errors.join("\n ")}")
        end
      end
    end

    # Validates that all entries in the _param_hash_ exists in the given param_struct, that their type conforms
    # with the corresponding param_struct element and that all required values are provided.
    # An error message is created for each problem found.
    #
    # @param params_struct [PStructType] Struct to use for validation
    # @param param_hash [Hash<String,Object>] The parameters to validate
    # @param missing_ok [Boolean] Do not generate errors on missing parameters
    # @return [Array<Mismatch>] An array of found errors. An empty array indicates no errors.
    def describe_struct_signature(params_struct, param_hash, missing_ok = false)
      param_type_hash = params_struct.hashed_elements
      result =  param_hash.each_key.reject { |name| param_type_hash.include?(name) }.map { |name| InvalidParameter.new(nil, name) }

      params_struct.elements.each do |elem|
        name = elem.name
        value = param_hash[name]
        value_type = elem.value_type
        if param_hash.include?(name)
          result << describe(value_type, TypeCalculator.singleton.infer_set(value).generalize, [ParameterPathElement.new(name)]) unless value_type.instance?(value)
        else
          result << MissingParameter.new(nil, name) unless elem.key_type.assignable?(PUndefType::DEFAULT) unless missing_ok
        end
      end
      result
    end

    def describe_signatures(closure, signatures, args_tuple)
      error_arrays = []
      signatures.each_with_index do |signature, index|
        error_arrays << describe_signature_arguments(signature, args_tuple, [SignaturePathElement.new(index)])
      end

      # Skip block checks if all signatures have argument errors
      unless error_arrays.all? { |a| !a.empty? }
        block_arrays = []
        signatures.each_with_index do |signature, index|
          block_arrays << describe_signature_block(signature, args_tuple, [SignaturePathElement.new(index)])
        end
        bc_count = block_arrays.count { |a| !a.empty? }
        if bc_count == block_arrays.size
          # Skip argument errors when all alternatives have block errors
          error_arrays = block_arrays
        elsif bc_count > 0
          # Merge errors giving argument errors precedence over block errors
          error_arrays.each_with_index { |a, index| error_arrays[index] = block_arrays[index] if a.empty? }
        end
      end
      return nil if error_arrays.empty?

      label = closure == 'lambda' ? 'block' : "'#{closure}'"
      errors = merge_descriptions(0, CountMismatch, error_arrays)
      if errors.size == 1
        "#{label}#{errors[0]}"
      else
        if signatures.size == 1
          sig = signatures[0]
          result = ["#{label} expected (#{signature_string(sig)})"]
          result.concat(error_arrays[0].map { |e| "  rejected:#{e.chop_path(0)}" })
        else
          result = ["#{label} expected one of:"]
          signatures.each_with_index do |sg, index|
            result << "  (#{signature_string(sg)})"
            result.concat(error_arrays[index].map { |e| "    rejected:#{e.chop_path(0)}" })
          end
        end
        result.join("\n")
      end
    end

    def describe_signature_arguments(signature, args_tuple, path)
      params_tuple = signature.type.param_types
      params_size_t = params_tuple.size_type || TypeFactory.range(*params_tuple.size_range)

      if args_tuple.is_a?(PTupleType)
        arg_types = args_tuple.types
      elsif args_tuple.is_a?(PArrayType)
        arg_types = Array.new(params_tuple.types.size, args_tuple.element_type || PUndefType::DEFAULT)
      else
        return [TypeMismatch.new(path, params_tuple, args_tuple)]
      end

      if arg_types.last.kind_of_callable?
        # Check other arguments
        arg_count = arg_types.size - 1
        describe_no_block_arguments(signature, arg_types, path, params_size_t, TypeFactory.range(arg_count, arg_count), arg_count)
      else
        args_size_t = TypeFactory.range(*args_tuple.size_range)
        describe_no_block_arguments(signature, arg_types, path, params_size_t, args_size_t, arg_types.size)
      end
    end

    def describe_signature_block(signature, args_tuple, path)
      param_block_t = signature.block_type
      arg_block_t = args_tuple.is_a?(PTupleType) ? args_tuple.types.last : nil
      if TypeCalculator.is_kind_of_callable?(arg_block_t)
        # Can't pass a block to a callable that doesn't accept one
        if param_block_t.nil?
          [UnexpectedBlock.new(path)]
        else
          # Check that the block is of the right type
          describe(param_block_t, arg_block_t, path + [BlockPathElement.new])
        end
      else
        # Check that the block is optional
        if param_block_t.nil? || param_block_t.assignable?(PUndefType::DEFAULT)
          EMPTY_ARRAY
        else
          [MissingRequiredBlock.new(path)]
        end
      end
    end

    def describe_no_block_arguments(signature, atypes, path, expected_size, actual_size, arg_count)
      # not assignable if the number of types in actual is outside number of types in expected
      if expected_size.assignable?(actual_size)
        etypes = signature.type.param_types.types
        enames = signature.parameter_names
        arg_count.times do |index|
          adx = index >= etypes.size ? etypes.size - 1 : index
          etype = etypes[adx]
          descriptions = describe(etype, atypes[index], path + [ParameterPathElement.new(enames[adx])])
          return descriptions unless descriptions.empty?
        end
        EMPTY_ARRAY
      else
        [CountMismatch.new(path, expected_size, actual_size)]
      end
    end

    def describe_PVariantType(expected, actual, path)
      variant_descriptions = []
      expected.types.each_with_index do |vt, index|
        d = describe(vt, actual, path + [VariantPathElement.new(index)])
        return EMPTY_ARRAY if d.empty?
        variant_descriptions << d
      end
      merge_descriptions(path.length, SizeMismatch, variant_descriptions)
    end

    def merge_descriptions(varying_path_position, size_mismatch_class, variant_descriptions)
      descriptions = variant_descriptions.flatten
      [size_mismatch_class, MissingRequiredBlock, UnexpectedBlock, TypeMismatch].each do |mismatch_class|
        mismatches = descriptions.select { |desc| desc.is_a?(mismatch_class) }
        if mismatches.size == variant_descriptions.size
          # If they all have the same canonical path, then we can compact this into one
          generic_mismatch = mismatches.inject do |prev, curr|
            break nil unless prev.canonical_path == curr.canonical_path
            prev.merge(prev.path, curr)
          end
          unless generic_mismatch.nil?
            # Report the generic mismatch and skip the rest
            descriptions = [generic_mismatch]
            break
          end
        end
      end
      descriptions = descriptions.uniq
      descriptions.size == 1 ? [descriptions[0].chop_path(varying_path_position)] : descriptions
    end

    def describe_POptionalType(expected, actual, path)
      actual.is_a?(PUndefType) ? [] : describe(expected.optional_type, actual, path)
    end

    def describe_PEnumType(expected, actual, path)
      [PatternMismatch.new(path, expected, actual)]
    end

    def describe_PPatternType(expected, actual, path)
      [PatternMismatch.new(path, expected, actual)]
    end

    def describe_PStructType(expected, actual, path)
      elements = expected.elements
      descriptions = []
      if actual.is_a?(PStructType)
        h2 = actual.hashed_elements.clone
        elements.each do |e1|
          key = e1.name
          e2 = h2.delete(key)
          if e2.nil?
            descriptions << MissingKey.new(path, key) unless e1.key_type.assignable?(PUndefType::DEFAULT)
          else
            descriptions.concat(describe(e1.key_type, e2.key_type, path + [MemberKeyPathElement.new(key)])) unless e1.key_type.assignable?(e2.key_type)
            descriptions.concat(describe(e1.value_type, e2.value_type, path + [MemberPathElement.new(key)])) unless e1.value_type.assignable?(e2.value_type)
          end
        end
        h2.each_key { |key| descriptions << ExtraneousKey.new(path, key) }
      elsif actual.is_a?(PHashType)
        actual_size = actual.size_type || PCollectionType::DEFAULT_SIZE
        expected_size = PIntegerType.new(elements.count { |e| !e.type.assignable?(PUndefType::DEFAULT) }, elements.size)
        if expected_size.assignable?(actual_size)
          if actual_size.to == 0 || PStringType::NON_EMPTY.assignable?(actual.key_type)
            descriptions.concat(describe(e.type, actual.element_type, path + [MemberPathElement.new(e.key)]))
          else
            descriptions << TypeMismatch(path, @non_empty_string_, actual.key_type)
          end
        else
          descriptions << SizeMismatch(path, expected_size, actual_size)
        end
      else
        descriptions << TypeMismatch.new(path, expected, actual)
      end
      descriptions
    end

    def describe_PTupleType(expected, actual, path)
      describe_tuple(expected, actual, path, SizeMismatch)
    end

    def describe_argument_tuple(expected, actual, path)
      describe_tuple(expected, actual, path, CountMismatch)
    end

    def describe_tuple(expected, actual, path, size_mismatch_class)
      return if expected == actual || expected.types.empty? && (actual.is_a?(PArrayType))
      expected_size = expected.size_type || TypeFactory.range(*expected.size_range)

      if actual.is_a?(PTupleType)
        actual_size = actual.size_type || TypeFactory.range(*actual.size_range)

        # not assignable if the number of types in actual is outside number of types in expected
        if expected_size.assignable?(actual_size)
          etypes = expected.types
          descriptions = []
          actual.types.each_with_index do |atype, index|
            adx = index >= etypes.size ? etypes.size - 1 : index
            etype = etypes[adx]
            descriptions.concat(describe(etypes[adx], atype, path + [ArrayPathElement.new(adx)]))
          end
          descriptions
        else
          [size_mismatch_class.new(path, expected_size, actual_size)]
        end
      elsif actual.is_a?(PArrayType)
        t2_entry = actual.element_type

        if t2_entry.nil?
          # Array of anything can not be assigned (unless tuple is tuple of anything) - this case
          # was handled at the top of this method.
          #
          [TypeMismatch.new(path, expected, actual)]
        else
          expected_size = expected.size_type || TypeFactory.range(*expected.size_range)
          actual_size = actual.size_type || PCollectionType::DEFAULT_SIZE
          if expected_size.assignable?(actual_size)
            descriptions = []
            expected.types.each_with_index do |etype, index|
              descriptions.concat(describe(etype, actual.element_type, path + [ArrayPathElement.new(index)]))
            end
            descriptions
          else
            [size_mismatch_class.new(path, expected_size, actual_size)]
          end
        end
      else
        [TypeMismatch.new(path, expected, actual)]
      end
    end

    def describe_PCallableType(expected, actual, path)
      if actual.is_a?(PCallableType)
        # nil param_types means, any other Callable is assignable
        if expected.param_types.nil?
          EMPTY_ARRAY
        else
          # NOTE: these tests are made in reverse as it is calling the callable that is constrained
          # (it's lower bound), not its upper bound
          param_errors = describe_argument_tuple(expected.param_types, actual.param_types, path)
          if param_errors.empty?
            # names are ignored, they are just information
            # Blocks must be compatible
            this_block_t = expected.block_type || PUndefType::DEFAULT
            that_block_t = actual.block_type || PUndefType::DEFAULT
            if that_block_t.assignable?(this_block_t)
              EMPTY_ARRAY
            else
              [TypeMismatch.new(path + BlockPathElement.new, this_block_t, that_block_t)]
            end
          else
            param_errors
          end
        end
      else
        [TypeMismatch.new(path, expected, actual)]
      end
    end

    def describe_PAnyType(expected, actual, path)
      expected.assignable?(actual) ? EMPTY_ARRAY : [TypeMismatch.new(path, expected, actual)]
    end

    def describe(expected, actual, path)
      case expected
      when PVariantType
        describe_PVariantType(expected, actual, path)
      when PStructType
        describe_PStructType(expected, actual, path)
      when PTupleType
        describe_PTupleType(expected, actual, path)
      when PCallableType
        describe_PCallableType(expected, actual, path)
      when POptionalType
        describe_POptionalType(expected, actual, path)
      when PPatternType
        describe_PPatternType(expected, actual, path)
      when PEnumType
        describe_PEnumType(expected, actual, path)
      else
        describe_PAnyType(expected, actual, path)
      end
    end

    # Produces a string for the signature(s)
    #
    # @api private
    def signature_string(signature)
      param_types = signature.type.param_types
      param_names = signature.parameter_names

      from, to = param_types.size_range
      if from == 0 && to == 0
        # No parameters function
        return ''
      end

      required_count = from
      types =
        case param_types
        when PTupleType
          param_types.types
        when PArrayType
          [param_types.element_type]
        end
      tc = TypeCalculator.singleton

      # join type with names (types are always present, names are optional)
      # separate entries with comma
      #
      param_names = Array.new(types.size, '') if param_names.empty?
      limit = param_names.size
      result = param_names.each_with_index.map do |name, index|
        type = types[index] || types[-1]
        indicator = ''
        if to == Float::INFINITY && index == limit - 1
          # Last is a repeated_param.
          indicator = from == param_names.size ? '+' : '*'
        elsif optional(index, required_count)
          indicator = '?'
          type = type.optional_type if type.is_a?(POptionalType)
        end
        "#{tc.string(type)} #{name}#{indicator}"
      end.join(', ')

      # If there is a block, include it
      case signature.type.block_type
      when POptionalType
        result << ', ' unless result == ''
        result << "#{signature.type.block_type.optional_type} #{signature.block_name}?"
      when PCallableType
        result << ', ' unless result == ''
        result << "#{signature.type.block_type} #{signature.block_name}"
      when NilClass
        # nothing
      end
      result
    end

    # Why oh why Ruby do you not have a standard Math.max ?
    # @api private
    def max(a, b)
      a >= b ? a : b
    end

    # @api private
    def optional(index, required_count)
      count = index + 1
      count > required_count
    end
  end
end
end
