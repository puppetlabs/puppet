module Puppet::Pops
module Serialization
  # Class that can process an arbitrary object into a value that is assignable to `Data`.
  #
  # @api public
  class ToDataConverter
    include Evaluator::Runtime3Support

    # Convert the given _value_ according to the given _options_ and return the result of the conversion
    #
    # @param value [Object] the value to convert
    # @param options {Symbol => <Boolean,String>} options hash
    # @option options [Boolean] :rich_data `true` if rich data is enabled
    # @option options [Boolean] :local_references use local references instead of duplicating complex entries
    # @option options [Boolean] :type_by_reference `true` if Object types are converted to references rather than embedded.
    # @option options [Boolean] :symbol_as_string `true` if Symbols should be converted to strings (with type loss)
    # @option options [String] :path_prefix String to prepend to path in warnings and errors
    # @return [Data] the processed result. An object assignable to `Data`.
    #
    # @api public
    def self.convert(value, options = EMPTY_HASH)
      new(options).convert(value)
    end

    # Create a new instance of the processor
    #
    # @param options {Symbol => Object} options hash
    # @option options [Boolean] :rich_data `true` if rich data is enabled
    # @option options [Boolean] :local_references use local references instead of duplicating complex entries
    # @option options [Boolean] :type_by_reference `true` if Object types are converted to references rather than embedded.
    # @option options [Boolean] :symbol_as_string `true` if Symbols should be converted to strings (with type loss)
    # @option options [String] :message_prefix String to prepend to path in warnings and errors
    # @option semantic [Object] :semantic object to pass to the issue reporter
    def initialize(options = EMPTY_HASH)
      @type_by_reference = options[:type_by_reference]
      @type_by_reference = true if @type_by_reference.nil?

      @local_reference = options[:local_reference]
      @local_reference = true if @local_reference.nil?

      @symbol_as_string = options[:symbol_as_string]
      @symbol_as_string = false if @symbol_as_string.nil?

      @rich_data = options[:rich_data]
      @rich_data = false if @rich_data.nil?

      @message_prefix = options[:message_prefix]
      @semantic = options[:semantic]
    end

    # Convert the given _value_
    #
    # @param value [Object] the value to convert
    # @return [Data] the processed result. An object assignable to `Data`.
    #
    # @api public
    def convert(value)
      @path = []
      @values = {}
      to_data(value)
    end

    private

    def path_to_s
      s = @message_prefix || ''
      s << JsonPath.to_json_path(@path)[1..-1]
      s
    end

    def to_data(value)
      if value.nil? || Types::PScalarDataType::DEFAULT.instance?(value)
        value
      elsif :default == value
        if @rich_data
          { PCORE_TYPE_KEY => PCORE_TYPE_DEFAULT }
        else
          serialization_issue(Issues::SERIALIZATION_DEFAULT_CONVERTED_TO_STRING, :path => path_to_s)
          'default'
        end
      elsif value.is_a?(Symbol)
        if @symbol_as_string
          value.to_s
        elsif @rich_data
          { PCORE_TYPE_KEY => PCORE_TYPE_SYMBOL, PCORE_VALUE_KEY => value.to_s }
        else
          unknown_to_string_with_warning(value)
        end
      elsif value.instance_of?(Array)
        process(value) do
          result = []
          value.each_with_index do |elem, index|
            with(index) { result << to_data(elem) }
          end
          result
        end
      elsif value.instance_of?(Hash)
        process(value) do
          if value.keys.all? { |key| key.is_a?(String) }
            result = {}
            value.each_pair { |key, elem| with(key) { result[key] = to_data(elem) } }
            result
          else
            non_string_keyed_hash_to_data(value)
          end
        end
      elsif value.instance_of?(Types::PSensitiveType::Sensitive)
        process(value) do
          { PCORE_TYPE_KEY => PCORE_TYPE_SENSITIVE, PCORE_VALUE_KEY => to_data(value.unwrap) }
        end
      else
        unknown_to_data(value)
      end
    end

    # If `:local_references` is enabled, then the `object_id` will be associated with the current _path_ of
    # the context the first time this method is called. The method then returns the result of  yielding to
    # the given block. Subsequent calls with a value that has the same `object_id` will instead return a
    # reference based on the given path.
    #
    # If `:local_references` is disabled, then this method performs a check for endless recursion before
    # it yields to the given block. The result of yielding is returned.
    #
    # @param value [Object] the value
    # @yield The block that will produce the data for the value
    # @return [Data] the result of yielding to the given block, or a hash denoting a reference
    #
    # @api private
    def process(value, &block)
      if @local_reference
        id = value.object_id
        ref = @values[id]
        if ref.nil?
          @values[id] = @path.dup
          yield
        elsif ref.instance_of?(Hash)
          ref
        else
          json_ref = JsonPath.to_json_path(ref)
          if json_ref.nil?
            # Complex key and hence no way to reference the prior value. The value must therefore be
            # duplicated which in turn introduces a risk for endless recursion in case of self
            # referencing structures
            with_recursive_guard(value, &block)
          else
            @values[id] = { PCORE_TYPE_KEY => PCORE_LOCAL_REF_SYMBOL, PCORE_VALUE_KEY => json_ref }
          end
        end
      else
        with_recursive_guard(value, &block)
      end
    end

    # Pushes `key` to the end of the path and yields to the given block. The
    # `key` is popped when the yield returns.
    # @param key [Object] the key to push on the current path
    # @yield The block that will produce the returned value
    # @return [Object] the result of yielding to the given block
    #
    # @api private
    def with(key)
      @path.push(key)
      value = yield
      @path.pop
      value
    end

    # @param value [Object] the value to use when checking endless recursion
    # @yield The block that will produce the data
    # @return [Data] the result of yielding to the given block
    def with_recursive_guard(value)
      id = value.object_id
      if @recursive_lock
        if @recursive_lock.include?(id)
          serialization_issue(Issues::SERIALIZATION_ENDLESS_RECURSION, :type_name => value.class.name)
        end
        @recursive_lock[id] = true
      else
        @recursive_lock = { id => true }
      end
      v = yield
      @recursive_lock.delete(id)
      v
    end

    def unknown_to_data(value)
      @rich_data ? value_to_data_hash(value) : unknown_to_string_with_warning(value)
    end

    def unknown_key_to_string_with_warning(value)
      str = unknown_to_string(value)
      serialization_issue(Issues::SERIALIZATION_UNKNOWN_KEY_CONVERTED_TO_STRING, :path => path_to_s, :klass => value.class, :value => str)
      str
    end

    def unknown_to_string_with_warning(value)
      str = unknown_to_string(value)
      serialization_issue(Issues::SERIALIZATION_UNKNOWN_CONVERTED_TO_STRING, :path => path_to_s, :klass => value.class, :value => str)
      str
    end

    def unknown_to_string(value)
      value.is_a?(Regexp) ? Puppet::Pops::Types::PRegexpType.regexp_to_s_with_delimiters(value) : value.to_s
    end

    def non_string_keyed_hash_to_data(hash)
      if @rich_data
        to_key_extended_hash(hash)
      else
        result = {}
        hash.each_pair do |key, value|
          if key.is_a?(Symbol) && @symbol_as_string
            key = key.to_s
          elsif !key.is_a?(String)
            key = unknown_key_to_string_with_warning(key)
          end
          with(key) { result[key] = to_data(value) }
        end
        result
      end
    end

    # A Key extended hash is a hash whose keys are not entirely strings. Such a hash
    # cannot be safely represented as JSON or YAML
    #
    # @param hash {Object => Object} the hash to process
    # @return [String => Data] the representation of the extended hash
    def to_key_extended_hash(hash)
      key_value_pairs = []
      hash.each_pair do |key, value|
        key = to_data(key)
        key_value_pairs << key
        key_value_pairs << with(key) { to_data(value) }
      end
      { PCORE_TYPE_KEY => PCORE_TYPE_HASH, PCORE_VALUE_KEY => key_value_pairs }
    end

    def value_to_data_hash(value)
      pcore_type = value.is_a?(Types::PuppetObject) ? value._pcore_type : Types::TypeCalculator.singleton.infer(value)
      if pcore_type.is_a?(Puppet::Pops::Types::PRuntimeType)
        unknown_to_string_with_warning(value)
      else
        pcore_tv = pcore_type_to_data(pcore_type)
        if pcore_type.roundtrip_with_string?
          {
            PCORE_TYPE_KEY => pcore_tv,

            # Scalar values are stored using their default string representation
            PCORE_VALUE_KEY => Types::StringConverter.singleton.convert(value)
          }
        elsif pcore_type.implementation_class.respond_to?(:_pcore_init_from_hash)
          process(value) do
            {
              PCORE_TYPE_KEY => pcore_tv,
            }.merge(to_data(value._pcore_init_hash))
          end
        else
          process(value) do
            (names, _, required_count) = pcore_type.parameter_info(value.class)
            args = names.map { |name| value.send(name) }

            # Pop optional arguments that are default
            while args.size > required_count
              break unless pcore_type[names[args.size-1]].default_value?(args.last)
              args.pop
            end
            result = {
              PCORE_TYPE_KEY => pcore_tv
            }
            args.each_with_index do |val, idx|
              key = names[idx]
              with(key) { result[key] = to_data(val) }
            end
            result
          end
        end
      end
    end

    def pcore_type_to_data(pcore_type)
      type_name = pcore_type.name
      if @type_by_reference  || type_name.start_with?('Pcore::')
        type_name
      else
        with(PCORE_TYPE_KEY) { to_data(pcore_type) }
      end
    end
    private :pcore_type_to_data

    def serialization_issue(issue, options = EMPTY_HASH)
      semantic = @semantic
      if semantic.nil?
        tos = Puppet::Pops::PuppetStack.top_of_stack
        if tos.empty?
          semantic = Puppet::Pops::SemanticError.new(issue, nil, EMPTY_HASH)
        else
          file, line = stacktrace
          semantic = Puppet::Pops::SemanticError.new(issue, nil, {:file => file, :line => line})
        end
      end
      optionally_fail(issue,  semantic, options)
    end
  end
end
end
