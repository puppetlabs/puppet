require 'msgpack'

module Puppet::Pops
module Serialization
module Extension
  # 0x00 - 0x0F are reserved for low-level serialization / tabulation extensions
  INNER_TABULATION = 0x00
  TABULATION = 0x01

  # 0x10 - 0x1F are reserved for structural extensions
  ARRAY_START = 0x10
  MAP_START = 0x11
  OBJECT_START = 0x12

  # 0x20 - 0x2f reserved for special extension objects
  DEFAULT = 0x20
  COMMENT = 0x21
  TYPE_DEFAULT = 0x22

  # 0x30 - 0x7f reserved for mapping of specific runtime classes
  REGEXP = 0x30
  TYPE_REFERENCE = 0x31
  SYMBOL = 0x32
  TIME   = 0x33
  TIMESTAMP = 0x34
  VERSION = 0x35
  VERSION_RANGE = 0x36

  # Marker module indicating whether or not an object is tabulated or not
  module NotTabulated; end

  # Marker module for objects that starts a sequence, i.e. ArrayStart, MapStart, and ObjectStart
  module SequenceStart; end

  class Default
    include NotTabulated
    INSTANCE = Default.new
  end

  class Tabulation
    include NotTabulated
    attr_reader :index
    def initialize(index)
      @index = index
    end
  end

  class InnerTabulation < Tabulation
  end

  class MapStart
    include NotTabulated
    include SequenceStart
    attr_reader :size
    def initialize(size)
      @size = size
    end

    def sequence_size
      @size * 2
    end
  end

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
