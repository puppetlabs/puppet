require 'spec_helper'
require 'puppet_spec/character_encoding'

require 'puppet/rest/compression'

describe Puppet::Rest::Compression do
  let(:data)            { "decompresseddata" }
  let(:compressed_zlib) { Zlib::Deflate.deflate(data) }
  let(:compressed_gzip) do
    str = StringIO.new
    writer = Zlib::GzipWriter.new(str)
    writer.write(data)
    writer.close.string
  end

  describe "when decompressing response body" do
    context "without compression" do
      it "should return untransformed response body with no content-encoding" do
        expect(Puppet::Rest::Compression.decompress(nil, data)).to eq(data)
      end

      it "should return untransformed response body with 'identity' content-encoding" do
        expect(Puppet::Rest::Compression.decompress('identity', data)).to eq(data)
      end
    end

    context "with 'zlib' content-encoding" do
      it "should use a Zlib inflater" do
        expect(Puppet::Rest::Compression.decompress('deflate', compressed_zlib)).to eq(data)
      end
    end

    context "with 'gzip' content-encoding" do
      it "should use a GzipReader" do
        expect(Puppet::Rest::Compression.decompress('gzip', compressed_gzip)).to eq(data)
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

        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
          decompressed = Puppet::Rest::Compression.decompress('gzip', compressed_body)
          # By default Zlib::GzipReader decompresses into Encoding.default_external, and we want to ensure our result is BINARY too
          expect(decompressed.encoding).to eq(Encoding::BINARY)
          expect(decompressed).to eq("\"foo\xDB\xBF\xE1\x9A\xA0\xF0\xA0\x9C\x8E\"".force_encoding(Encoding::BINARY))
        end
      end
    end
  end
end
