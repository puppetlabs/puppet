require_relative 'extension'

module Puppet::Pops
module Serialization
  class Deserializer
    def initialize(reader, loader)
      @read = []
      @reader = reader
      @loader = loader
    end

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
      when Extension::ObjectStart
        type_name = val.type_name
        type = Types::TypeParser.singleton.parse(type_name, @loader)
        raise SerializationError, "No implementation mapping found for Puppet Type #{type_name}" if type.is_a?(Types::PTypeReferenceType)
        type.read(val.attribute_count, self)
      when Numeric, String, true, false, nil, Time
        val
      else
        remember(val)
      end
    end

    def reset
      @reader.reset
    end

    def remember(value)
      @read << value
      value
    end
  end
end
end