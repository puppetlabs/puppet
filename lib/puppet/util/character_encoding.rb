# A module to centralize heuristics/practices for managing character encoding in Puppet

module Puppet::Util::CharacterEncoding
  class << self
    # Warning! This is a destructive method - the string supplied is modified!
    # Given a string, attempts to convert the string to UTF-8. Conversion uses
    # encode! - the string's internal byte representation is modifed to UTF-8.
    #
    # This method is intended for situations where we generally trust that the
    # string's bytes are a faithful representation of the current encoding
    # associated with it, and can use it as a starting point for transcoding
    # (conversion) to UTF-8.
    #
    # @api public
    # @param [String] string a string to transcode
    # @return [nil] (string is modified in place)
    def convert_to_utf_8!(string)
      original_encoding = string.encoding

      begin
        if original_encoding == Encoding::UTF_8
          if string.valid_encoding?
            # String is aleady valid UTF-8 - noop
            return nil
          else
            Puppet.debug(_("%{value} is already labeled as UTF-8 but this encoding is invalid. It cannot be transcoded by Puppet.") %
              { value: string.dump })
          end
        else
          # If the string comes to us as BINARY encoded, we don't know what it
          # started as. However, to encode! we need a starting place, and our
          # best guess is whatever the system currently is (default_external).
          # So set external_encoding to default_external before we try to
          # transcode to UTF-8.
          string.force_encoding(Encoding.default_external) if original_encoding == Encoding::BINARY
          string.encode!(Encoding::UTF_8)
        end
      rescue EncodingError => detail
        # Ensure the string retains it original external encoding since
        # we've failed
        string.force_encoding(original_encoding) if original_encoding == Encoding::BINARY
        # Catch both our own self-determined failure to transcode as well as any
        # error on ruby's part, ie Encoding::UndefinedConversionError on a
        # failure to encode!.
        Puppet.debug(_("%{error}: %{value} cannot be transcoded by Puppet.") %
          { error: detail.inspect, value: string.dump })
      end
      return nil
    end

    # Warning! This is a destructive method - the string supplied is modified!
    # Given a string, tests if that string's bytes represent valid UTF-8, and if
    # so sets the external encoding of the string to UTF-8. Does not modify the
    # byte representation of the string. If the string does not represent valid
    # UTF-8, does not set the external encoding.
    #
    # This method is intended for situations where we do not believe that the
    # encoding associated with a string is an accurate reflection of its actual
    # bytes, i.e., effectively when we believe Ruby is incorrect in its assertion
    # of the encoding of the string.
    #
    # @api public
    # @param [String] string set external encoding (re-label) to utf-8
    # @return [nil] (string is modified in place)
    def override_encoding_to_utf_8!(string)
      if valid_utf_8_bytes?(string)
        string.force_encoding(Encoding::UTF_8)
      else
        Puppet.debug(_("%{value} is not valid UTF-8 and result of overriding encoding would be invalid.") % { value: string.dump })
      end
      nil
    end

    # Given a string, return a copy of that string with any invalid byte
    # sequences in its current encoding replaced with "?". We use "?" to make
    # sure our output is consistent across ruby versions and encodings, and
    # because calling scrub on a non-UTF8 string with the unicode replacement
    # character "\uFFFD" results in an Encoding::CompatibilityError.
    # @param string a string to remove invalid byte sequences from
    # @return a copy of string invalid byte sequences replaced by "?" character
    # @note does not modify encoding, but new string will have different bytes
    #   from original. Only needed for ruby 1.9.3 support.
    def scrub(string)
      if string.respond_to?(:scrub)
        string.scrub
      else
        encoding = string.encoding
        replacement_character = ([Encoding::UTF_8, Encoding::UTF_16LE].include?(encoding) ? "\uFFFD" : '?').encode(encoding)
        string.chars.map { |c| c.valid_encoding? ? c : replacement_character }.join
      end
    end

    private

    # Do our best to determine if a string is valid UTF-8 via String#valid_encoding? without permanently
    # modifying or duplicating the string due to performance concerns
    # @api private
    # @param [String] string a string to test
    # @return [Boolean] whether we think the string is UTF-8 or not
    def valid_utf_8_bytes?(string)
      string.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end
  end
end
