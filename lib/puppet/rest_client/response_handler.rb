require 'zlib'
require 'stringio'

module Puppet::Rest
  module ResponseHandler
    # Returns the content_type, stripping any appended charset, and the
    # body, decompressed if necessary (content-encoding is checked inside
    # uncompress_body)
    def self.parse_response(response)
      if response.content_type
        [ response.content_type.gsub(/\s*;.*$/,''), uncompress_body(response) ]
      else
        raise _("No content type in http response; cannot parse")
      end
    end


    # return an uncompressed body if the response has been
    # compressed
    def self.uncompress_body(response)
      case response.headers['Content-Encoding']
      when 'gzip'
        # ZLib::GzipReader has an associated encoding, by default Encoding.default_external
        return Zlib::GzipReader.new(StringIO.new(response.body), :encoding => Encoding::BINARY).read
      when 'deflate'
        return Zlib::Inflate.new.inflate(response.body)
      when nil, 'identity'
        return response.body
      else
        raise Net::HTTPError.new(_("Unknown content encoding - %{encoding}") % { encoding: response.headers['Content-Encoding'] }, response)
      end
    end
  end
end
