require 'spec_helper'
require 'puppet/rest_client/response_handler'

ResponseHandler = Puppet::Rest::ResponseHandler

describe ResponseHandler do

  let(:data)            { "uncompresseddata" }
  let(:response)        { stub 'response' }
  let(:compressed_zlib) { Zlib::Deflate.deflate(data) }
  let(:compressed_gzip) do
    str = StringIO.new
    writer = Zlib::GzipWriter.new(str)
    writer.write(data)
    writer.close.string
  end

  def stubs_response_with(response, content_encoding, body)
    response.stubs(:headers).returns({ 'Content-Encoding' => content_encoding })
    response.stubs(:body).returns(body)
  end

  describe "when uncompressing response body" do
    context "without compression" do
      it "should return untransformed response body with no content-encoding" do
        stubs_response_with(response, nil, data)

        expect(ResponseHandler.uncompress_body(response)).to eq(data)
      end

      it "should return untransformed response body with 'identity' content-encoding" do
        stubs_response_with(response, 'identity', data)

        expect(ResponseHandler.uncompress_body(response)).to eq(data)
      end
    end

    context "with 'zlib' content-encoding" do
      it "should use a Zlib inflater" do
        stubs_response_with(response, 'deflate', compressed_zlib)

        expect(ResponseHandler.uncompress_body(response)).to eq(data)
      end

    end

    context "with 'gzip' content-encoding" do
      it "should use a GzipReader" do
        stubs_response_with(response, 'gzip', compressed_gzip)

        expect(ResponseHandler.uncompress_body(response)).to eq(data)
      end

      it "should correctly decompress PSON containing UTF-8 in Binary Encoding" do
        # Simulate a compressed response body containing PSON containing UTF-8
        # using different UTF-8 widths:

        # \u06ff - ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
        # \u16A0 - ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
        # \u{2070E} - 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142

        pson = "foo\u06ff\u16A0\u{2070E}".to_pson # unicode expression eqivalent of "foo\xDB\xBF\xE1\x9A\xA0\xF0\xA0\x9C\x8E\" per above
        writer = Zlib::GzipWriter.new(StringIO.new)
        writer.write(pson)
        compressed_body = writer.close.string

        begin
          default_external = Encoding.default_external
          Encoding.default_external = Encoding::ISO_8859_1

          stubs_response_with(response, 'gzip', compressed_body)

          uncompressed = ResponseHandler.uncompress_body(response)
          # By default Zlib::GzipReader decompresses into Encoding.default_external, and we want to ensure our result is BINARY too
          expect(uncompressed.encoding).to eq(Encoding::BINARY)
          expect(uncompressed).to eq("\"foo\xDB\xBF\xE1\x9A\xA0\xF0\xA0\x9C\x8E\"".force_encoding(Encoding::BINARY))
        ensure
          Encoding.default_external = default_external
        end
      end
    end
  end
end
