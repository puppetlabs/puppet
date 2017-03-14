require 'puppet/network/http'

module Puppet::Network::HTTP::Compression
  # from https://github.com/ruby/ruby/blob/v2_1_3/lib/net/http/generic_request.rb#L40
  ACCEPT_ENCODING = "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"

  # this module function allows to use the right underlying
  # methods depending on zlib presence
  def module
    return(Puppet.features.zlib? ? Active : None)
  end
  module_function :module

  module Active
    require 'zlib'
    require 'stringio'

    # return an uncompressed body if the response has been
    # compressed
    def uncompress_body(response)
      case response['content-encoding']
      when 'gzip'
        # ZLib::GzipReader has an associated encoding, by default Encoding.default_external
        return Zlib::GzipReader.new(StringIO.new(response.body), :encoding => Encoding::BINARY).read
      when 'deflate'
        return Zlib::Inflate.new.inflate(response.body)
      when nil, 'identity'
        return response.body
      else
        raise Net::HTTPError.new(_("Unknown content encoding - %{encoding}") % { encoding: response['content-encoding'] }, response)
      end
    end

    def uncompress(response)
      raise Net::HTTPError.new("No block passed", response) unless block_given?

      case response['content-encoding']
      when 'gzip','deflate'
        uncompressor = ZlibAdapter.new
      when nil, 'identity'
        uncompressor = IdentityAdapter.new
      else
        raise Net::HTTPError.new(_("Unknown content encoding - %{encoding}") % { encoding: response['content-encoding'] }, response)
      end

      begin
        yield uncompressor
      ensure
        uncompressor.close
      end
    end

    def add_accept_encoding(headers={})
      headers['accept-encoding'] = Puppet::Network::HTTP::Compression::ACCEPT_ENCODING
      headers
    end

    # This adapters knows how to uncompress both 'zlib' stream (the deflate algorithm from Content-Encoding)
    # and GZip streams.
    class ZlibAdapter
      def initialize(uncompressor = Zlib::Inflate.new(15 + 32))
        # Create an inflater that knows to parse GZip streams and zlib streams.
        # This uses a property of the C Zlib library, documented as follow:
        #   windowBits can also be greater than 15 for optional gzip decoding. Add
        #   32 to windowBits to enable zlib and gzip decoding with automatic header
        #   detection, or add 16 to decode only the gzip format (the zlib format will
        #   return a Z_DATA_ERROR).  If a gzip stream is being decoded, strm->adler is
        #   a crc32 instead of an adler32.
        @uncompressor = uncompressor
        @first = true
      end

      def uncompress(chunk)
        out = @uncompressor.inflate(chunk)
        @first = false
        return out
      rescue Zlib::DataError
        # it can happen that we receive a raw deflate stream
        # which might make our inflate throw a data error.
        # in this case, we try with a verbatim (no header)
        # deflater.
        @uncompressor = Zlib::Inflate.new
        if @first then
          @first = false
          retry
        end
        raise
      end

      def close
        @uncompressor.finish
      ensure
        @uncompressor.close
      end
    end
  end

  module None
    def uncompress_body(response)
      response.body
    end

    def add_accept_encoding(headers)
      headers
    end

    def uncompress(response)
      yield IdentityAdapter.new
    end
  end

  class IdentityAdapter
    def uncompress(chunk)
      chunk
    end

    def close
    end
  end
end
