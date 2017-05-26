module Puppet::Pops
module Serialization
  class FromDataConverter
    def self.convert(value)
      new.convert(value)
    end

    def initialize(options = EMPTY_HASH)
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
      @pcore_type_procs.default = proc do |hash, type_name|
        value = hash.include?(PCORE_VALUE_KEY) ? hash[PCORE_VALUE_KEY] : hash.reject { |key, _| PCORE_TYPE_KEY == key }
        pcore_type_hash_to_value(data_to_pcore_type(type_name), value)
      end
    end

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
      @current[@key] = value unless @current.nil?
      with_value(value, &block) if block_given?
      value
    end

    def pcore_type_hash_to_value(pcore_type, value)
      if value.is_a?(Hash)
        # Complex object
        if value.empty?
          build(pcore_type.create)
        elsif pcore_type.implementation_class.respond_to?(:_pcore_init_from_hash)
          build(pcore_type.allocate) do
            @current._pcore_init_from_hash(with_value({}) { value.each_pair { |key, elem| with(key) { convert(elem) } } })
          end
        else
          build(pcore_type.allocate) do
            args = with_value([]) { value.values.each_with_index { |elem, idx| with(idx) { convert(elem) }}}
            @current.send(:initialize, *args)
          end
        end
      elsif value.is_a?(String)
        build(pcore_type.create(value))
      else
        raise SerializationError, _('Cannot create a %{type_name} from a %{arg_class') %
            { :type_name => pcore_type.name, :arg_class => value.class.name }
      end
    end

    def data_to_pcore_type(pcore_type)
      if pcore_type.is_a?(Hash)
        without_value { convert(pcore_type) }
      else
        type = Types::TypeParser.singleton.parse(pcore_type, @loader)
        if type.is_a?(Types::PTypeReferenceType)
          raise SerializationError, _('No implementation mapping found for Puppet Type %{type_name}') % { type_name: pcore_type }
        end
        type
      end
    end
  end
end
end
