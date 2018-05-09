module Puppet::Rest
  module Compression
    # Returns the decompressed response body. Returns the body as-is
    # if not compressed.
    # @param [String] content_encoding the encoding of the body
    # @param [String] body the response body, or a chunk of it
    def self.decompress(content_encoding, body)
      case content_encoding
      when 'gzip'
        return Zlib::GzipReader.new(StringIO.new(body), :encoding => Encoding::BINARY).read
      when 'deflate'
        return Zlib::Inflate.new.inflate(body)
      when nil, 'identity'
        return body
      else
        Puppet.err _("unknown content encoding - %{encoding}") % { encoding: content_encoding }
      end
    end
  end
end
