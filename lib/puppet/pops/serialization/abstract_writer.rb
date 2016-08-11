require_relative 'extension'

module Puppet::Pops
module Serialization

MAX_INTEGER =  0x7fffffffffffffff
MIN_INTEGER = -0x8000000000000000

# Abstract class for protocol specific writers such as MsgPack or JSON
# The abstract write is capable of writing the primitive scalars:
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
# - Timestamp
# - Default
#
# @api public
class AbstractWriter
  # @param [MessagePack::Packer,JSON::Packer] packer the underlying packer stream
  # @param [Hash] options
  # @option options [Boolean] :tabulate `true` if tabulation is enabled (which is the default).
  # @param [DebugPacker,nil] extension_packer Optional specific extension packer. Only used for debug output
  # @api public
  def initialize(packer, options, extension_packer = nil)
    @tabulate = options[:tabulate]
    @tabulate = true if @tabulate.nil?
    @written = {}
    @packer = packer
    @extension_packer = extension_packer.nil? ? packer : extension_packer
    register_types
  end

  # Tell the underlying packer to flush.
  # @api public
  def finish
    @packer.flush
  end

  # Write a value on the underlying stream
  # @api public
  def write(value)
    written = false
    case value
    when Integer
      # not tabulated, but integers larger than 64-bit cannot be allowed.
      raise SerializationError, 'Integer out of bounds' if value > MAX_INTEGER || value < MIN_INTEGER
    when Numeric, Symbol, Extension::NotTabulated, true, false, nil
      # not tabulated
    else
      if @tabulate
        index = @written[value]
        if index.nil?
          @packer.write(value)
          written = true
          @written[value] = @written.size
        else
          value = Extension::InnerTabulation.new(index)
        end
      end
    end
    @packer.write(value) unless written
  end

  # Called from extension callbacks only
  #
  # @api private
  def build_payload
    raise SerializationError, "Internal error: Class #{self.class} does not implement method 'build_payload'"
  end

  # @api private
  def extension_packer
    @extension_packer
  end

  # Called from extension callbacks only
  #
  # @api private
  def write_tpl_qname(ep, qname)
    names = qname.split('::')
    ep.write(names.size)
    names.each {|n| write_tpl(ep, n)}
  end

  # Called from extension callbacks only
  #
  # @api private
  def write_tpl(ep, value)
    raise ArgumentError, 'Internal error. Integers cannot be tabulated in extension payload' if value.is_a?(Integer)
    if @tabulate
      index = @written[value]
      if index.nil?
        @written[value] = @written.size
      else
        value = index
      end
    end
    ep.write(value)
  end

  # @api private
  def register_type(extension_number, payload_class, &block)
    @packer.register_type(extension_number, payload_class, &block)
  end

  # @api private
  def register_types
    # 0x00 - 0x0F are reserved for low-level serialization / tabulation extensions

    register_type(Extension::INNER_TABULATION, Extension::InnerTabulation) do |o|
      build_payload { |ep| ep.write(o.index) }
    end

    register_type(Extension::TABULATION, Extension::Tabulation) do |o|
      build_payload { |ep| ep.write(o.index) }
    end

    # 0x10 - 0x1F are reserved for structural extensions

    register_type(Extension::ARRAY_START, Extension::ArrayStart) do |o|
      build_payload { |ep| ep.write(o.size) }
    end

    register_type(Extension::MAP_START, Extension::MapStart) do |o|
      build_payload { |ep| ep.write(o.size) }
    end

    register_type(Extension::OBJECT_START, Extension::ObjectStart) do |o|
      build_payload { |ep| write_tpl_qname(ep, o.type_name); ep.write(o.attribute_count) }
    end

    # 0x20 - 0x2f reserved for special extension objects

    register_type(Extension::DEFAULT, Extension::Default) do |o|
      build_payload { |ep| }
    end

    register_type(Extension::COMMENT, Extension::Comment) do |o|
      build_payload { |ep| ep.write(o.comment) }
    end

    # 0x30 - 0x7f reserved for mapping of specific runtime classes

    register_type(Extension::REGEXP, Regexp) do |o|
      build_payload { |ep| ep.write(o.source) }
    end

    register_type(Extension::TYPE_REFERENCE, Types::PTypeReferenceType) do |o|
      build_payload { |ep| write_tpl_qname(ep, o.type_string) }
    end

    register_type(Extension::SYMBOL, Symbol) do |o|
      build_payload { |ep| ep.write(o.to_s) }
    end

    register_type(Extension::TIME, Time) do |o|
      build_payload { |ep| ep.write(o.tv_sec); ep.write(o.tv_nsec) }
    end

    register_type(Extension::VERSION, Semantic::Version) do |o|
      build_payload { |ep| ep.write(o.to_s) }
    end

    register_type(Extension::VERSION_RANGE, Semantic::VersionRange) do |o|
      build_payload { |ep| ep.write(o.to_s) }
    end
  end
end
end
end

