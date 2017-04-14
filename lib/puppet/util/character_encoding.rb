# A module to centralize heuristics/practices for managing character encoding in Puppet

module Puppet::Util::CharacterEncoding
  class << self
    # Warning! This is a destructive method - the string supplied is modified!
    # @api public
    # @param [String] string a string to transcode / force_encode to utf-8
    # @return [String] string if already utf-8, OR
    #   the same string with external encoding set to utf-8 if bytes are valid utf-8 OR
    #   the same string transcoded to utf-8 OR
    #   nil upon a failure to legitimately set external encoding or transcode string
    def convert_to_utf_8!(string)
      currently_valid = string.valid_encoding?

      begin
        if string.encoding == Encoding::UTF_8
          if currently_valid
            return string
          else
            # If a string is currently believed to be UTF-8, but is also not
            # valid_encoding?, we have no recourse but to fail because we have no
            # idea what encoding this string originally came from where it *was*
            # valid - all we know is it's not currently valid UTF-8.
            raise EncodingError
          end
        elsif valid_utf_8_bytes?(string)
          # Before we try to transcode the string, check if it is valid UTF-8 as
          # currently constitued (in its non-UTF-8 encoding), and if it is, limit
          # ourselves to setting the external encoding of the string to UTF-8
          # rather than actually transcoding it. We do this to handle
          # a couple scenarios:

          # The first scenario is that the string was originally valid UTF-8 but
          # the current puppet run is not in a UTF-8 environment. In this case,
          # the string will likely have invalid byte sequences (i.e.,
          # string.valid_encoding? == false), and attempting to transcode will
          # fail with Encoding::InvalidByteSequenceError, referencing the
          # invalid byte sequence in the original, pre-transcode, string. We
          # might have gotten here, for example, if puppet is run first in a
          # user context with UTF-8 encoding (setting the "is" value to UTF-8)
          # and then later run via cron without UTF-8 specified, resulting in in
          # EN_US (ISO-8859-1) on many systems. In this scenario we're
          # effectively best-guessing this string originated as UTF-8 and only
          # set external encoding to UTF-8 - transcoding would have failed
          # anyway.

          # The second scenario (more rare, I expect) is that this string does
          # NOT have invalid byte sequences (string.valid_encoding? == true),
          # but is *ALSO valid unicode*.
          # Our example case is "\u16A0" - "RUNIC LETTER FEHU FEOH FE"
          # http://www.fileformat.info/info/unicode/char/16A0/index.htm
          # 0xE1 0x9A 0xA0 / 225 154 160
          # These bytes are valid in ISO-8859-1 but the character they represent
          # transcodes cleanly in ruby to *different* characters in UTF-8.
          # That's not what we want if the user intended the original string as
          # UTF-8. We can only guess, so if the string is valid UTF-8 as
          # currently constituted, we default to assuming the string originated
          # in UTF-8 and do not transcode it - we only set external encoding.
          return string.force_encoding(Encoding::UTF_8)
        elsif currently_valid
          # If the string is not currently valid UTF-8 but it can be transcoded
          # (it is valid in its current encoding), we can guess this string was
          # not originally unicode. Transcode it to UTF-8. For strings with
          # original encodings like SHIFT_JIS, this should be the final result.
          return string.encode!(Encoding::UTF_8)
        else
          # If the string is neither valid UTF-8 as-is nor valid in its current
          # encoding, fail. It requires user remediation.
          raise EncodingError
        end
      rescue EncodingError => detail
        # Catch both our own self-determined failure to transcode as well as any
        # error on ruby's part, ie Encoding::UndefinedConversionError on a
        # failure to encode!.
        Puppet.debug(_("%{error}: %{value} is not valid UTF-8 and cannot be transcoded by Puppet.") %
          { error: detail.inspect, value: string.dump })
        return nil
      end
    end

    private

    # Do our best to determine if a string is valid UTF-8 via String#valid_encoding? without permanently
    # modifying or duplicating the string due to performance concerns
    # @api private
    # @param [String] string a string to test
    # @return [Boolean] whether we think the string is UTF-8 or not
    def valid_utf_8_bytes?(string)
      original_encoding = string.encoding
      valid = string.force_encoding(Encoding::UTF_8).valid_encoding?
      string.force_encoding(original_encoding)
      valid
    end
  end
end
