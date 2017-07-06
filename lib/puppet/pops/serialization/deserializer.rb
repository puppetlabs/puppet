require_relative 'extension'

module Puppet::Pops
module Serialization
  # The deserializer is capable of reading, arrays, maps, and complex objects using an underlying protocol reader. It takes care of
  # resolving tabulations and assembling complex objects. The type of the complex objects are resolved using a loader.
  # @api public
  class Deserializer
    # Provides access to the reader.
    # @api private
    attr_reader :reader, :loader

    # @param [AbstractReader] reader the reader used when reading primitive objects from a stream
    # @param [Loader::Loader] loader the loader used when resolving names of types
    # @api public
    def initialize(reader, loader)
      @read = []
      @reader = reader
      @loader = loader
    end

    # Read the next value from the reader.
    #
    # @return [Object] the value that was read
    # @api public
    def read
      val = @reader.read
      case val
      when Extension::Tabulation
        @read[val.index]
      when Extension::Default
        :default
      when Extension::ArrayStart
        result = remember([])
        val.size.times { result << read }
        result
      when Extension::MapStart
        result = remember({})
        val.size.times { key = read; result[key] = read }
        result
      when Extension::SensitiveStart
        Types::PSensitiveType::Sensitive.new(read)
      when Extension::PcoreObjectStart
        type_name = val.type_name
        type = Types::TypeParser.singleton.parse(type_name, @loader)
        raise SerializationError, _("No implementation mapping found for Puppet Type %{type_name}") % { type_name: type_name } if type.is_a?(Types::PTypeReferenceType)
        result = type.read(val.attribute_count, self)
        if result.is_a?(Types::PObjectType)
          existing_type = loader.load(:type, result.name)
          if result.eql?(existing_type)
            result = existing_type
          else
            # Add result to the loader unless it is equal to the existing_type. The add
            # will only succeed when the existing_type is nil.
            loader.add_entry(:type, result.name, result, nil)
          end
        end
        result
      when Extension::ObjectStart
        type = read
        type.read(val.attribute_count - 1, self)
      when Numeric, String, true, false, nil
        val
      else
        remember(val)
      end
    end

    # Remember that a value has been read. This means that the value is given an index
    # and that subsequent reads of a tabulation with that index should return the value.
    # @param [Object] value The value to remember
    # @return [Object] the argument
    # @api private
    def remember(value)
      @read << value
      value
    end
  end
end
end
