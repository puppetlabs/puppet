require_relative 'extension'

module Puppet::Pops
module Serialization
  # The serializer is capable of writing, arrays, maps, and complex objects using an underlying protocol writer. It takes care of
  # tabulating and disassembling complex objects.
  # @api public
  class Serializer
    # Provides access to the writer.
    # @api private
    attr_reader :writer

    # @param writer [AbstractWriter] the writer that is used for writing primitive values
    # @param options [{String, Object}] serialization options
    # @option options [Boolean] :type_by_reference `true` if Object types are serialized by name only.
    # @api public
    def initialize(writer, options = EMPTY_HASH)
      @written = {}
      @writer = writer
      @options = options
    end

    # Tell the underlying writer to finish
    # @api public
    def finish
      @writer.finish
    end

    # Write an object
    # @param [Object] value the object to write
    # @api public
    def write(value)
      case value
      when Integer, Float, String, true, false, nil
        @writer.write(value)
      when :default
        @writer.write(Extension::Default::INSTANCE)
      else
        index = @written[value.object_id]
        if index.nil?
          write_tabulated_first_time(value)
        else
          @writer.write(Extension::Tabulation.new(index))
        end
      end
    end

    # Write the start of an array.
    # @param [Integer] size the size of the array
    # @api private
    def start_array(size)
      @writer.write(Extension::ArrayStart.new(size))
    end

    # Write the start of a map (hash).
    # @param [Integer] size the number of entries in the map
    # @api private
    def start_map(size)
      @writer.write(Extension::MapStart.new(size))
    end

    # Write the start of a complex pcore object
    # @param [String] type_ref the name of the type
    # @param [Integer] attr_count the number of attributes in the object
    # @api private
    def start_pcore_object(type_ref, attr_count)
      @writer.write(Extension::PcoreObjectStart.new(type_ref, attr_count))
    end

    # Write the start of a complex object
    # @param [Integer] attr_count the number of attributes in the object
    # @api private
    def start_object(attr_count)
      @writer.write(Extension::ObjectStart.new(attr_count))
    end

    def push_written(value)
      @written[value.object_id] = @written.size
    end

    # Write the start of a sensitive object
    # @api private
    def start_sensitive
      @writer.write(Extension::SensitiveStart::INSTANCE)
    end

    def type_by_reference?
      @options[:type_by_reference] == true
    end

    def to_s
      "#{self.class.name} with #{@writer}"
    end

    def inspect
      to_s
    end

    # First time write of a tabulated object. This means that the object is written and then remembered. Subsequent writes
    # of the same object will yield a write of a tabulation index instead.
    # @param [Object] value the value to write
    # @api private
    def write_tabulated_first_time(value)
      case
      when value.instance_of?(Symbol),
          value.instance_of?(Regexp),
          value.instance_of?(SemanticPuppet::Version),
          value.instance_of?(SemanticPuppet::VersionRange),
          value.instance_of?(Time::Timestamp),
          value.instance_of?(Time::Timespan),
          value.instance_of?(Types::PBinaryType::Binary),
          value.is_a?(URI)
        push_written(value)
        @writer.write(value)
      when value.instance_of?(Array)
        push_written(value)
        start_array(value.size)
        value.each { |elem| write(elem) }
      when value.instance_of?(Hash)
        push_written(value)
        start_map(value.size)
        value.each_pair { |key, val| write(key); write(val) }
      when value.instance_of?(Types::PSensitiveType::Sensitive)
        start_sensitive
        write(value.unwrap)
      when value.instance_of?(Types::PTypeReferenceType)
        push_written(value)
        @writer.write(value)
      when value.is_a?(Types::PuppetObject)
        value._pcore_type.write(value, self)
      else
        impl_class = value.class
        type = Loaders.implementation_registry.type_for_module(impl_class)
        raise SerializationError, _("No Puppet Type found for %{klass}") % { klass: impl_class.name } unless type.is_a?(Types::PObjectType)
        type.write(value, self)
      end
    end
  end
end
end
