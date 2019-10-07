require_relative 'extension'
require_relative 'time_factory'

module Puppet::Pops
module Serialization
# Abstract class for protocol specific readers such as MsgPack or JSON
# The abstract reader is capable of reading the primitive scalars:
# - Boolean
# - Integer
# - Float
# - String
# and, by using extensions, also
# - Array start
# - Map start
# - Object start
# - Regexp
# - Version
# - VersionRange
# - Timespan
# - Timestamp
# - Default
#
# @api public
class AbstractReader
  # @param [MessagePack::Unpacker,JSON::Unpacker] unpacker The low lever unpacker that delivers the primitive objects
  # @param [MessagePack::Unpacker,JSON::Unpacker] extension_unpacker Optional unpacker for extensions. Defaults to the unpacker
  # @api public
  def initialize(unpacker, extension_unpacker = nil)
    @read = []
    @unpacker = unpacker
    @extension_unpacker = extension_unpacker.nil? ? unpacker : extension_unpacker
    register_types
  end

  # Read an object from the underlying unpacker
  # @return [Object] the object that was read
  # @api public
  def read
    obj = @unpacker.read
    case obj
    when Extension::InnerTabulation
      @read[obj.index]
    when Numeric, Symbol, Extension::NotTabulated, true, false, nil
      # not tabulated
      obj
    else
      @read << obj
      obj
    end
  end

  # @return [Integer] The total count of unique primitive values that has been read
  # @api private
  def primitive_count
    @read.size
  end

  # @api private
  def read_payload(data)
    raise SerializationError, "Internal error: Class #{self.class} does not implement method 'read_payload'"
  end

  # @api private
  def read_tpl_qname(ep)
    Array.new(ep.read) { read_tpl(ep) }.join('::')
  end

  # @api private
  def read_tpl(ep)
    obj = ep.read
    case obj
    when Integer
      @read[obj]
    else
      @read << obj
      obj
    end
  end

  # @api private
  def extension_unpacker
    @extension_unpacker
  end

  # @api private
  def register_type(extension_number, &block)
    @unpacker.register_type(extension_number, &block)
  end

  # @api private
  def register_types
    register_type(Extension::INNER_TABULATION) do |data|
      read_payload(data) { |ep| Extension::InnerTabulation.new(ep.read) }
    end

    register_type(Extension::TABULATION) do |data|
      read_payload(data) { |ep| Extension::Tabulation.new(ep.read) }
    end

    register_type(Extension::ARRAY_START) do |data|
      read_payload(data) { |ep| Extension::ArrayStart.new(ep.read) }
    end

    register_type(Extension::MAP_START) do |data|
      read_payload(data) { |ep| Extension::MapStart.new(ep.read) }
    end

    register_type(Extension::PCORE_OBJECT_START) do |data|
      read_payload(data) { |ep| type_name = read_tpl_qname(ep); Extension::PcoreObjectStart.new(type_name, ep.read) }
    end

    register_type(Extension::OBJECT_START) do |data|
      read_payload(data) { |ep| Extension::ObjectStart.new(ep.read) }
    end

    register_type(Extension::DEFAULT) do |data|
      read_payload(data) { |ep| Extension::Default::INSTANCE }
    end

    register_type(Extension::COMMENT) do |data|
      read_payload(data) { |ep| Extension::Comment.new(ep.read) }
    end

    register_type(Extension::SENSITIVE_START) do |data|
      read_payload(data) { |ep| Extension::SensitiveStart::INSTANCE }
    end

    register_type(Extension::REGEXP) do |data|
      read_payload(data) { |ep| Regexp.new(ep.read) }
    end

    register_type(Extension::TYPE_REFERENCE) do |data|
      read_payload(data) { |ep| Types::PTypeReferenceType.new(ep.read) }
    end

    register_type(Extension::SYMBOL) do |data|
      read_payload(data) { |ep| ep.read.to_sym }
    end

    register_type(Extension::TIME) do |data|
      read_payload(data) do |ep|
        sec = ep.read
        nsec = ep.read
        Time::Timestamp.new(sec * 1000000000 + nsec)
      end
    end

    register_type(Extension::TIMESPAN) do |data|
      read_payload(data) do |ep|
        sec = ep.read
        nsec = ep.read
        Time::Timespan.new(sec * 1000000000 + nsec)
      end
    end

    register_type(Extension::VERSION) do |data|
      read_payload(data) { |ep| SemanticPuppet::Version.parse(ep.read) }
    end

    register_type(Extension::VERSION_RANGE) do |data|
      read_payload(data) { |ep| SemanticPuppet::VersionRange.parse(ep.read) }
    end

    register_type(Extension::BASE64) do |data|
      read_payload(data) { |ep| Types::PBinaryType::Binary.from_base64_strict(ep.read) }
    end

    register_type(Extension::BINARY) do |data|
      # The Ruby MessagePack implementation have special treatment for "ASCII-8BIT" strings. They
      # are written as binary data.
      read_payload(data) { |ep| Types::PBinaryType::Binary.new(ep.read) }
    end

    register_type(Extension::URI) do |data|
      read_payload(data) { |ep| URI(ep.read) }
    end
  end
end
end
end
