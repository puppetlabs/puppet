# A module to centralize heuristics/practices for managing character encoding in Puppet
require 'puppet/util'

module Puppet::Util::CharacterEncoding
  class << self
    #TODO make encoding warnings a category/silenceable#.

    # @api public
    # @param [String] string a string to transcode / force_encode to utf-8
    # @return [String] string if already utf-8, OR
    #   a copy of string with external encoding set to utf-8 if bytes are valid utf-8 OR
    #   a copy of string transcoded to utf-8
    # @raise [Puppet::Error] a failure to legitimately set external encoding or
    #   transcode string
    def convert_to_utf_8(string)
      return string if string.encoding == Encoding::UTF_8

      value_to_encode = string.dup

      begin
        if valid_utf_8?(value_to_encode)
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
          value_to_encode.force_encoding(Encoding::UTF_8)
        elsif transcodable?(value_to_encode)
          # If the string is not currently valid UTF-8 but it can be transcoded,
          # we can guess this string was not originally unicode. We need it to
          # be now, so transcode it to UTF-8. For strings with original
          # encodings like SHIFT_JIS, this should be the final result.
          value_to_encode.encode!(Encoding::UTF_8)
        else
          # If the string is neither valid UTF-8 as-is nor is transcodable, fail
          # at this point. It requires user remediation.
          raise EncodingError
        end
      rescue EncodingError => detail
        # catch both our own self-determined failure to transcode as well as any
        # error on ruby's part, ie Encoding::InvalidByteSequenceError or
        # Encoding::UndefinedConversionError.
        raise Puppet::Error, _("#{detail.inspect}: #{value_to_encode.dump} is not valid UTF-8 and cannot be transcoded by Puppet.")
      end

      return value_to_encode
    end

    private

    # Do our best to determine if a string is valid
    # UTF-8 via String#valid_encoding?
    # @api private
    # @param [String] string a string to test
    # @return [Boolean] whether we think the string is UTF-8 or not
    def valid_utf_8?(string)
      string.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    # Trying to encode! a string with existing invalid byte sequences raises
    # Encoding::InvalidByteSequenceError, so we don't consider it transcodable
    # @api private
    # @param [String] string a string to test
    # @return [Boolean] whether we think the string can be transcoded
    def transcodable?(string)
      string.valid_encoding?
    end
  end
end
