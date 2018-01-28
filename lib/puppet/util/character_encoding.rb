# A module to centralize heuristics/practices for managing character encoding in Puppet

module Puppet::Util::CharacterEncoding
  class << self
    # Given a string, attempts to convert a copy of the string to UTF-8. Conversion uses
    # encode - the string's internal byte representation is modifed to UTF-8.
    #
    # This method is intended for situations where we generally trust that the
    # string's bytes are a faithful representation of the current encoding
    # associated with it, and can use it as a starting point for transcoding
    # (conversion) to UTF-8.
    #
    # @api public
    # @param [String] string a string to transcode
    # @return [String] copy of the original string, in UTF-8 if transcodable
    def convert_to_utf_8(string)
      original_encoding = string.encoding
      string_copy = string.dup
      begin
        if original_encoding == Encoding::UTF_8
          if !string_copy.valid_encoding?
            Puppet.debug(_("%{value} is already labeled as UTF-8 but this encoding is invalid. It cannot be transcoded by Puppet.") %
              { value: string.dump })
          end
          # String is already valid UTF-8 - noop
          return string_copy
        else
          # If the string comes to us as BINARY encoded, we don't know what it
          # started as. However, to encode! we need a starting place, and our
          # best guess is whatever the system currently is (default_external).
          # So set external_encoding to default_external before we try to
          # transcode to UTF-8.
          string_copy.force_encoding(Encoding.default_external) if original_encoding == Encoding::BINARY
          return string_copy.encode(Encoding::UTF_8)
        end
      rescue EncodingError => detail
        # Set the encoding on our copy back to its original if we modified it
        string_copy.force_encoding(original_encoding) if original_encoding == Encoding::BINARY

        # Catch both our own self-determined failure to transcode as well as any
        # error on ruby's part, ie Encoding::UndefinedConversionError on a
        # failure to encode!.
        Puppet.debug(_("%{error}: %{value} cannot be transcoded by Puppet.") %
          { error: detail.inspect, value: string.dump })
        return string_copy
      end
    end

    # Given a string, tests if that string's bytes represent valid UTF-8, and if
    # so return a copy of the string with external encoding set to UTF-8. Does
    # not modify the byte representation of the string. If the string does not
    # represent valid UTF-8, does not set the external encoding.
    #
    # This method is intended for situations where we do not believe that the
    # encoding associated with a string is an accurate reflection of its actual
    # bytes, i.e., effectively when we believe Ruby is incorrect in its
    # assertion of the encoding of the string.
    #
    # @api public
    # @param [String] string to set external encoding (re-label) to utf-8
    # @return [String] a copy of string with external encoding set to utf-8, or
    # a copy of the original string if override would result in invalid encoding.
    def override_encoding_to_utf_8(string)
      string_copy = string.dup
      original_encoding = string_copy.encoding
      return string_copy if original_encoding == Encoding::UTF_8
      if string_copy.force_encoding(Encoding::UTF_8).valid_encoding?
        return string_copy
      else
        Puppet.debug(_("%{value} is not valid UTF-8 and result of overriding encoding would be invalid.") % { value: string.dump })
        # Set copy back to its original encoding before returning
        return string_copy.force_encoding(original_encoding)
      end
    end

    REPLACEMENT_CHAR_MAP = {
      Encoding::UTF_8 => "\uFFFD",
      Encoding::UTF_16LE => "\xFD\xFF".force_encoding(Encoding::UTF_16LE),
    }

    # Given a string, return a copy of that string with any invalid byte
    # sequences in its current encoding replaced with the replacement character
    # "\uFFFD" (UTF-8) if the string is UTF-8 or UTF-16LE, or "?" otherwise.
    # @param string a string to remove invalid byte sequences from
    # @return a copy of string invalid byte sequences replaced by the unicode
    #   replacement character or "?" character
    # @note does not modify encoding, but new string will have different bytes
    #   from original. Only needed for ruby 1.9.3 support.
    def scrub(string)
      if string.respond_to?(:scrub)
        string.scrub
      else
        replacement_character = REPLACEMENT_CHAR_MAP[string.encoding] || '?'
        string.chars.map { |c| c.valid_encoding? ? c : replacement_character }.join
      end
    end
  end
end
