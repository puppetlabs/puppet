# frozen_string_literal: true

module Puppet::Pops
module Serialization
  # Class that can process an arbitrary object into a value that is assignable to `Data`
  # and where contents is converted from rich data to one of:
  # * Numeric (Integer, Float)
  # * Boolean
  # * Undef (nil)
  # * String
  # * Array
  # * Hash
  #
  # The conversion is lossy - the result cannot be deserialized to produce the original data types.
  # All rich values are transformed to strings..
  # Hashes with rich keys are transformed to use string representation of such keys.
  #
  # @api public
  class ToStringifiedConverter
    include Evaluator::Runtime3Support

    # Converts the given _value_ according to the given _options_ and return the result of the conversion
    #
    # @param value [Object] the value to convert
    # @param options {Symbol => <Boolean,String>} options hash
    # @option options [String] :message_prefix String to prepend to in warnings and errors
    # @option options [String] :semantic object (AST) to pass to the issue reporter
    # @return [Data] the processed result. An object assignable to `Data` with rich data stringified.
    #
    # @api public
    def self.convert(value, options = EMPTY_HASH)
      new(options).convert(value)
    end

    # Creates a new instance of the processor
    #
    # @param options {Symbol => Object} options hash
    # @option options [String] :message_prefix String to prepend to path in warnings and errors
    # @option semantic [Object] :semantic object to pass to the issue reporter
    def initialize(options = EMPTY_HASH)
      @message_prefix = options[:message_prefix]
      @semantic = options[:semantic]
    end

    # Converts the given _value_
    #
    # @param value [Object] the value to convert
    # @return [Data] the processed result. An object assignable to `Data` with rich data stringified.
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
      s << JsonPath.to_json_path(@path)[1..]
      s
    end

    def to_data(value)
      if value.instance_of?(String)
        to_string_or_binary(value)
      elsif value.nil? || Types::PScalarDataType::DEFAULT.instance?(value)
        value
      elsif :default == value
        'default'
      elsif value.is_a?(Symbol)
        value.to_s
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
          if value.keys.all? { |key| key.is_a?(String) && key != PCORE_TYPE_KEY && key != PCORE_VALUE_KEY }
            result = {}
            value.each_pair { |key, elem| with(key) { result[key] = to_data(elem) } }
            result
          else
            non_string_keyed_hash_to_data(value)
          end
        end
      else
        unknown_to_string(value)
      end
    end

    # Turns an ASCII-8BIT encoded string into a Binary, returns US_ASCII encoded and transforms all other strings to UTF-8
    # with replacements for non Unicode characters.
    # If String cannot be represented as UTF-8
    def to_string_or_binary(value)
      encoding = value.encoding
      if encoding == Encoding::ASCII_8BIT
        Puppet::Pops::Types::PBinaryType::Binary.from_binary_string(value).to_s
      else
        # Transform to UTF-8 (do not assume UTF-8 is correct) with source invalid byte
        # sequences and UTF-8 undefined characters replaced by the default unicode uFFFD character
        # (black diamond with question mark).
        value.encode(Encoding::UTF_8, encoding, :invalid => :replace, :undef => :replace)
      end
    end

    # Performs a check for endless recursion before
    # it yields to the given block. The result of yielding is returned.
    #
    # @param value [Object] the value
    # @yield The block that will produce the data for the value
    # @return [Data] the result of yielding to the given block, or a hash denoting a reference
    #
    # @api private
    def process(value, &block)
      with_recursive_guard(value, &block)
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

    # A hash key that is non conforming
    def unknown_key_to_string(value)
      unknown_to_string(value)
    end

    def unknown_to_string(value)
      if value.is_a?(Regexp)
        return Puppet::Pops::Types::PRegexpType.regexp_to_s_with_delimiters(value)

      elsif value.instance_of?(Types::PSensitiveType::Sensitive)
        # to_s does not differentiate between instances - if they were used as keys in a hash
        # the stringified result would override all Sensitive keys with the last such key's value
        # this adds object_id.
        #
        return "#<#{value}:#{value.object_id}>"

      elsif value.is_a?(Puppet::Pops::Types::PObjectType)
        # regular to_s on an ObjectType gives the entire definition
        return value.name

      end

      # Do a to_s on anything else
      result = value.to_s

      # The result may be ascii-8bit encoded without being a binary (low level object.inspect returns ascii-8bit string)
      # This can be the case if runtime objects have very simple implementation (no to_s or inspect method).
      # They are most likely not of Binary nature. Therefore the encoding is forced and only if it errors
      # will the result be taken as binary and encoded as base64 string.
      if result.encoding == Encoding::ASCII_8BIT
        begin
          result.force_encoding(Encoding::UTF_8)
        rescue
          # The result cannot be represented in UTF-8, make it a binary Base64 encoded string
          Puppet::Pops::Types::PBinaryType::Binary.from_binary_string(result).to_s
        end
      end
      result
    end

    def non_string_keyed_hash_to_data(hash)
      result = {}
      hash.each_pair do |key, value|
        if key.is_a?(Symbol)
          key = key.to_s
        elsif !key.is_a?(String)
          key = unknown_key_to_string(key)
        end
        if key == "__ptype" || key == "__pvalue"
          key = "reserved key: #{key}"
        end
        with(key) { result[key] = to_data(value) }
      end
      result
    end

    def serialization_issue(issue, options = EMPTY_HASH)
      semantic = @semantic
      if semantic.nil?
        tos = Puppet::Pops::PuppetStack.top_of_stack
        if tos.empty?
          semantic = Puppet::Pops::SemanticError.new(issue, nil, EMPTY_HASH)
        else
          file, line = stacktrace
          semantic = Puppet::Pops::SemanticError.new(issue, nil, { :file => file, :line => line })
        end
      end
      optionally_fail(issue, semantic, options)
    end
  end
end
end
