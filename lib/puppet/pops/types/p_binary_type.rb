require 'base64'
module Puppet::Pops
module Types

# A Puppet Language Type that represents binary data content (a sequence of 8-bit bytes).
# Instances of this data type can be created from `String` and `Array[Integer[0,255]]`
# values. Also see the `binary_file` function for reading binary content from a file.
#
# A `Binary` can be converted to `String` and `Array` form - see function `new` for
# the respective target data type for more information.
#
# Instances of this data type serialize as base 64 encoded strings when the serialization
# format is textual, and as binary content when a serialization format supports this.
#
# @api public
class PBinaryType < PAnyType

  # Represents a binary buffer
  # @api public
  class Binary
    attr_reader :binary_buffer

    # Constructs an instance of Binary from a base64 urlsafe encoded string (RFC 2045).
    # @param [String] A string with RFC 2045 compliant encoded binary
    #
    def self.from_base64(str)
      new(Base64.decode64(str))
    end

    # Constructs an instance of Binary from a base64 encoded string (RFC4648 with "URL and Filename
    # Safe Alphabet" (That is with '-' instead of '+', and '_' instead of '/').
    #
    def self.from_base64_urlsafe(str)
      new(Base64.urlsafe_decode64(str))
    end

    # Constructs an instance of Binary from a base64 strict encoded string (RFC 4648)
    # Where correct padding must be used and line breaks causes an error to be raised.
    #
    # @param [String] A string with RFC 4648 compliant encoded binary
    #
    def self.from_base64_strict(str)
      new(Base64.strict_decode64(str))
    end

    # Creates a new Binary from a String containing binary data. If the string's encoding
    # is not already ASCII-8BIT, a copy of the string is force encoded as ASCII-8BIT (that is Ruby's "binary" format).
    # This means that this binary will have the exact same content, but the string will considered
    # to hold a sequence of bytes in the range 0 to 255.
    #
    # The given string will be frozen as a side effect if it is in ASCII-8BIT encoding. If this is not
    # wanted, a copy should be given to this method.
    #
    # @param [String] A string with binary data
    # @api public
    #
    def self.from_binary_string(bin)
      new(bin)
    end

    # Creates a new Binary from a String containing text/binary in its given encoding. If the string's encoding
    # is not already UTF-8, the string is first transcoded to UTF-8.
    # This means that this binary will have the UTF-8 byte representation of the original string.
    # For this to be valid, the encoding used in the given string must be valid.
    # The validity of the given string is therefore asserted.
    #
    # The given string will be frozen as a side effect if it is in ASCII-8BIT encoding. If this is not
    # wanted, a copy should be given to this method.
    #
    # @param [String] A string with valid content in its given encoding
    # @return [Puppet::Pops::Types::PBinaryType::Binary] with the UTF-8 representation of the UTF-8 transcoded string
    # @api public
    #
    def self.from_string(encoded_string)
      enc = encoded_string.encoding.name
      unless encoded_string.valid_encoding?
        raise ArgumentError, _("The given string in encoding '%{enc}' is invalid. Cannot create a Binary UTF-8 representation") % { enc: enc }
      end
      # Convert to UTF-8 (if not already UTF-8), and then to binary
      encoded_string = (enc == "UTF-8") ? encoded_string.dup : encoded_string.encode('UTF-8')
      encoded_string.force_encoding("ASCII-8BIT")
      new(encoded_string)
    end

    # Creates a new Binary from a String containing raw binary data of unknown encoding. If the string's encoding
    # is not already ASCII-8BIT, a copy of the string is forced to ASCII-8BIT (that is Ruby's "binary" format).
    # This means that this binary will have the exact same content, but the string will considered
    # to hold a sequence of bytes in the range 0 to 255.
    #
    # @param [String] A string with binary data
    # @api private
    #
    def initialize(bin)
      # TODO: When Ruby 1.9.3 support is dropped change this to `bin.b` for binary encoding instead of force_encoding
      @binary_buffer = (bin.encoding.name == "ASCII-8BIT" ? bin : bin.dup.force_encoding("ASCII-8BIT")).freeze
    end

    # Presents the binary content as a string base64 encoded string (without line breaks).
    #
    def to_s
      Base64.strict_encode64(@binary_buffer)
    end

    # Returns the binary content as a "relaxed" base64 (standard) encoding where
    # the string is broken up with new lines.
    def relaxed_to_s
      Base64.encode64(@binary_buffer)
    end

    # Returns the binary content as a url safe base64 string (where + and / are replaced by - and _)
    #
    def urlsafe_to_s
      Base64.urlsafe_encode64(@binary_buffer)
    end

    def hash
      @binary_buffer.hash
    end

    def eql?(o)
      self.class == o.class && @binary_buffer == o.binary_buffer
    end

    def ==(o)
      self.eql?(o)
    end

    def length()
      @binary_buffer.length
    end
  end

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  # Only instances of Binary are instances of the PBinaryType
  #
  def instance?(o, guard = nil)
    o.is_a?(Binary)
  end

  def eql?(o)
    self.class == o.class
  end

  # Binary uses the strict base64 format as its string representation
  # @return [TrueClass] true
  def roundtrip_with_string?
    true
  end

  # @api private
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_Binary, type.loader) do
      local_types do
        type 'ByteInteger = Integer[0,255]'
        type 'Base64Format = Enum["%b", "%u", "%B", "%s", "%r"]'
        type 'StringHash = Struct[{value => String, "format" => Optional[Base64Format]}]'
        type 'ArrayHash = Struct[{value => Array[ByteInteger]}]'
        type 'BinaryArgsHash = Variant[StringHash, ArrayHash]'
      end

      # Creates a binary from a base64 encoded string in one of the formats %b, %u, %B, %s, or %r
      dispatch :from_string do
        param 'String', :str
        optional_param 'Base64Format', :format
      end

      dispatch :from_array do
        param 'Array[ByteInteger]', :byte_array
      end

      # Same as from_string, or from_array, but value and (for string) optional format are given in the form
      # of a hash.
      #
      dispatch :from_hash do
        param 'BinaryArgsHash', :hash_args
      end

      def from_string(str, format = nil)
        format ||= '%B'
        case format
        when "%b"
          # padding must be added for older rubies to avoid truncation
          padding = '=' * (str.length % 3)
          Binary.new(Base64.decode64(str + padding))

        when "%u"
          Binary.new(Base64.urlsafe_decode64(str))

        when "%B"
          Binary.new(Base64.strict_decode64(str))

        when "%s"
          Binary.from_string(str)

        when "%r"
          Binary.from_binary_string(str)

        else
          raise ArgumentError, "Unsupported Base64 format '#{format}'"
        end
      end

      def from_array(array)
        # The array is already known to have bytes in the range 0-255, or it is in error
        # Without this pack C would produce weird results
        Binary.from_binary_string(array.pack("C*"))
      end

      def from_hash(hash)
        case hash['value']
        when Array
          from_array(hash['value'])
        when String
          from_string(hash['value'], hash['format'])
        end
      end
    end
  end

  DEFAULT = PBinaryType.new

  protected

  def _assignable?(o, guard)
    o.class == self.class
  end

end
end
end
