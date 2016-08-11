module Puppet::Pops
module Serialization
module Extension
  # 0x00 - 0x0F are reserved for low-level serialization / tabulation extensions

  # Tabulation internal to the low level protocol reader/writer
  INNER_TABULATION = 0x00

  # Tabulation managed by the serializer / deserializer
  TABULATION = 0x01

  # 0x10 - 0x1F are reserved for structural extensions
  ARRAY_START = 0x10
  MAP_START = 0x11
  OBJECT_START = 0x12

  # 0x20 - 0x2f reserved for special extension objects
  DEFAULT = 0x20
  COMMENT = 0x21

  # 0x30 - 0x7f reserved for mapping of specific runtime classes
  REGEXP = 0x30
  TYPE_REFERENCE = 0x31
  SYMBOL = 0x32
  TIME   = 0x33
  TIMESPAN = 0x34
  VERSION = 0x35
  VERSION_RANGE = 0x36

  # Marker module indicating whether or not an instance is tabulated or not
  module NotTabulated; end

  # Marker module for objects that starts a sequence, i.e. ArrayStart, MapStart, and ObjectStart
  module SequenceStart; end

  # The class that triggers the use of the DEFAULT extension. It doesn't have any payload
  class Default
    include NotTabulated
    INSTANCE = Default.new
  end

  # The class that triggers the use of the TABULATION extension. The payload is the tabulation index
  class Tabulation
    include NotTabulated
    attr_reader :index
    def initialize(index)
      @index = index
    end
  end

  # Tabulation internal to the protocol reader/writer
  class InnerTabulation < Tabulation
  end

  # The class that triggers the use of the MAP_START extension. The payload is the map size (number of entries)
  class MapStart
    include NotTabulated
    include SequenceStart
    attr_reader :size
    def initialize(size)
      @size = size
    end

    # Sequence size is twice the map size since each entry is written as key and value
    def sequence_size
      @size * 2
    end
  end

  # The class that triggers the use of the ARRAY_START extension. The payload is the array size
  class ArrayStart
    include NotTabulated
    include SequenceStart
    attr_reader :size
    def initialize(size)
      @size = size
    end

    def sequence_size
      @size
    end
  end

  # The class that triggers the use of the OBJECT_START extension. The payload is the name of the object type and the
  # number of attributes in the instance.
  class ObjectStart
    include SequenceStart
    attr_reader :type_name, :attribute_count
    def initialize(type_name, attribute_count)
      @type_name = type_name
      @attribute_count = attribute_count
    end

    def hash
      @type_name.hash * 29 + attribute_count.hash
    end

    def eql?(o)
      o.is_a?(ObjectStart) && o.type_name == @type_name && o.attribute_count == @attribute_count
    end
    alias == eql?

    def sequence_size
      @attribute_count
    end
  end

  # The class that triggers the use of the COMMENT extension. The payload is comment text
  class Comment
    attr_reader :comment
    def initialize(comment)
      @comment = comment
    end

    def hash
      @comment.hash
    end

    def eql?(o)
      o.is_a?(Comment) && o.comment == @comment
    end
    alias == eql?
  end
end
end
end
