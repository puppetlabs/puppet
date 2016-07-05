require_relative 'extension'

module Puppet::Pops
module Serialization
  # The serializer is capable of writing, arrays, maps, and complex objects using an underlying protocol writer. It takes care of
  # tabulating and disassembling complex objects.
  # @api public
  class Serializer
    # @param [AbstractWriter] writer the writer that is used for writing primitive values
    # @api public
    def initialize(writer)
      @written = {}
      @writer = writer
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
      when Integer, Float, String, true, false, nil, Time
        @writer.write(value)
      when :default
        @writer.write(Extension::Default::INSTANCE)
      else
        index = @written[value.object_id]
        if index.nil?
          write_tabulated_first_time(value)
        else
          @writer.write(Extension::Tabulation.new(index)) unless index.nil?
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

    # Write the start of a complex object
    # @param [String] type_ref the name of the type
    # @param [Integer] attr_count the number of attributes in the object
    # @api private
    def start_object(type_ref, attr_count)
      @writer.write(Extension::ObjectStart.new(type_ref, attr_count))
    end

    # First time write of a tabulated object. This means that the object is written and then remembered. Subsequent writes
    # of the same object will yield a write of a tabulation index instead.
    # @param [Object] value the value to write
    # @api private
    def write_tabulated_first_time(value)
      @written[value.object_id] = @written.size
      case value
      when Symbol, Regexp, Semantic::Version, Semantic::VersionRange
        @writer.write(value)
      when Array
        start_array(value.size)
        value.each { |elem| write(elem) }
      when Hash
        start_map(value.size)
        value.each_pair { |key, val| write(key); write(val) }
      when Types::PTypeReferenceType
        @writer.write(value)
      when Types::PuppetObject
        value._ptype.write(value, self)
      else
        impl_class = value.class
        type = Loaders.implementation_registry.type_for_module(impl_class)
        raise SerializationError, "No Puppet Type found for #{impl_class.name}" unless type.is_a?(Types::PObjectType)
        type.write(value, self)
      end
    end
  end
end
end
