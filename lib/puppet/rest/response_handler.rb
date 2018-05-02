module Puppet::Rest
  module ResponseHandler

    # Processe and return the content type and body of the response
    # @param [Puppet::Rest::Response] response the HTTP response to process
    # @return [String, String] the content type (minus its encoding) and
    #         decompressed body of the response
    def self.parse_response(response)
      if response.content_type
        [ response.content_type.gsub(/\s*;.*$/, ''), decompress_body(response) ]
      else
        raise _("No content type in http response; cannot parse")
      end
    end

    # Return the decompressed response body. Returns the body as-is
    # if not compressed.
    # @param [Puppet::Rest::Response] response the HTTP response to process
    # @return [String] decompressed response body
    def self.decompress_body(response)
      case response.content_encoding
      when 'gzip'
        return Zlib::GzipReader.new(StringIO.new(response.body), :encoding => Encoding::BINARY).read
      when 'deflate'
        return Zlib::Inflate.new.inflate(response.body)
      when nil, 'identity'
        return response.body
      else
        Puppet.error _("Unknown content encoding - %{encoding}") % { encoding: response.content_encoding }
      end
    end
  end
end
