module Puppet::Pops
module Serialization
  class Builder
    def initialize(values)
      @values = values
      @resolved = true
    end

    def [](key)
      @values[key]
    end

    def []=(key, value)
      @values[key] = value
      @resolved = false if value.is_a?(Builder)
    end

    def resolve
      unless @resolved
        @resolved = true
        if @values.is_a?(Array)
          @values.each_with_index { |v, idx| @values[idx] = v.resolve if v.is_a?(Builder) }
        elsif @values.is_a?(Hash)
          @values.each_pair { |k, v| @values[k] = v.resolve if v.is_a?(Builder) }
        end
      end
      @values
    end
  end

  class ObjectHashBuilder < Builder
    def initialize(instance)
      super({})
      @instance = instance
    end

    def resolve
      @instance._pcore_init_from_hash(super)
      @instance
    end
  end

  class ObjectArrayBuilder < Builder
    def initialize(instance)
      super({})
      @instance = instance
    end

    def resolve
      @instance.send(:initialize, *super.values)
      @instance
    end
  end

  # Class that can process the `Data` produced by the {ToDataConverter} class and reassemble
  # the objects that were converted.
  #
  # @api public
  class FromDataConverter
    # Converts the given `Data` _value_ according to the given _options_ and returns the resulting `RichData`.
    #
    # @param value [Data] the value to convert
    # @param options {Symbol => <Boolean,String>} options hash
    # @option options [Loaders::Loader] :loader the loader to use. Can be `nil` in which case the default is
    #    determined by the {Types::TypeParser}.
    # @option options [Boolean] :allow_unresolved `true` to allow that rich_data hashes are kept "as is" if the
    #    designated '__pcore_type__' cannot be resolved. Defaults to `false`.
    # @return [RichData] the processed result.
    #
    # @api public
    def self.convert(value, options = EMPTY_HASH)
      new(options).convert(value)
    end

    # Creates a new instance of the processor
    #
    # @param options {Symbol => Object} options hash
    # @option options [Loaders::Loader] :loader the loader to use. Can be `nil` in which case the default is
    #    determined by the {Types::TypeParser}.
    # @option options [Boolean] :allow_unresolved `true` to allow that rich_data hashes are kept "as is" if the
    #    designated '__pcore_type__' cannot be resolved. Defaults to `false`.
    #
    # @api public
    def initialize(options = EMPTY_HASH)
      @allow_unresolved = options[:allow_unresolved]
      @allow_unresolved = false if @allow_unresolved.nil?
      @loader = options[:loader]

      @pcore_type_procs = {
        PCORE_TYPE_HASH => proc do |hash, _|
          value = hash[PCORE_VALUE_KEY]
          build({}) do
            top = value.size
            idx = 0
            while idx < top
              key = without_value { convert(value[idx]) }
              idx += 1
              with(key) { convert(value[idx]) }
              idx += 1
            end
          end
        end,

        PCORE_TYPE_SENSITIVE => proc do |hash, _|
          build(Types::PSensitiveType::Sensitive.new(convert(hash[PCORE_VALUE_KEY])))
        end,

        PCORE_TYPE_DEFAULT => proc do |_, _|
          build(:default)
        end,

        PCORE_TYPE_SYMBOL => proc do |hash, _|
          build(:"#{hash[PCORE_VALUE_KEY]}")
        end,

        PCORE_LOCAL_REF_SYMBOL => proc do |hash, _|
          build(JsonPath::Resolver.singleton.resolve(@root, hash[PCORE_VALUE_KEY]))
        end
      }
      @pcore_type_procs.default = proc do |hash, type_value|
        value = hash.include?(PCORE_VALUE_KEY) ? hash[PCORE_VALUE_KEY] : hash.reject { |key, _| PCORE_TYPE_KEY == key }
        if type_value.is_a?(Hash)
          type = without_value { convert(type_value) }
          if type.is_a?(Hash)
            raise SerializationError, _('Unable to deserialize type from %{type}') % { type: type } unless @allow_unresolved
            hash
          else
            pcore_type_hash_to_value(type, value)
          end
        else
          type = Types::TypeParser.singleton.parse(type_value, @loader)
          if type.is_a?(Types::PTypeReferenceType)
            unless @allow_unresolved
              raise SerializationError, _('No implementation mapping found for Puppet Type %{type_name}') % { type_name: type_value }
            end
            hash
          else
            pcore_type_hash_to_value(type, value)
          end
        end
      end
    end

    # Converts the given `Data` _value_ and returns the resulting `RichData`
    #
    # @param value [Data] the value to convert
    # @return [RichData] the processed result
    #
    # @api public
    def convert(value)
      if value.is_a?(Hash)
        pcore_type = value[PCORE_TYPE_KEY]
        if pcore_type
          @pcore_type_procs[pcore_type].call(value, pcore_type)
        else
          build({}) { value.each_pair { |key, elem| with(key) { convert(elem) }}}
        end
      elsif value.is_a?(Array)
        build([]) { value.each_with_index { |elem, idx| with(idx) { convert(elem)}}}
      else
        build(value)
      end
    end

    private

    def with(key)
      parent_key = @key
      @key = key
      yield
      @key = parent_key
    end

    def with_value(value)
      @root = value unless instance_variable_defined?(:@root)
      parent = @current
      @current = value
      yield
      @current = parent
      value
    end

    def without_value
      parent = @current
      @current = nil
      value = yield
      @current = parent
      value
    end

    def build(value, &block)
      vx = Builder.new(value)
      @current[@key] = vx unless @current.nil?
      with_value(vx, &block) if block_given?
      vx.resolve
    end

    def build_object(builder, &block)
      @current[@key] = builder unless @current.nil?
      with_value(builder, &block) if block_given?
      builder.resolve
    end

    def pcore_type_hash_to_value(pcore_type, value)
      if value.is_a?(Hash)
        # Complex object
        if value.empty?
          build(pcore_type.create)
        elsif pcore_type.implementation_class.respond_to?(:_pcore_init_from_hash)
          build_object(ObjectHashBuilder.new(pcore_type.allocate)) { value.each_pair { |key, elem| with(key) { convert(elem) } } }
        else
          build_object(ObjectArrayBuilder.new(pcore_type.allocate)) { value.each_pair { |key, elem| with(key) { convert(elem) } } }
        end
      elsif value.is_a?(String)
        build(pcore_type.create(value))
      else
        raise SerializationError, _('Cannot create a %{type_name} from a %{arg_class}') %
            { :type_name => pcore_type.name, :arg_class => value.class.name }
      end
    end
  end
end
end
