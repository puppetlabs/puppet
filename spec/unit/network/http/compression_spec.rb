#! /usr/bin/env ruby
require 'spec_helper'

describe "http compression" do
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
    response.stubs(:[]).with('content-encoding').returns(content_encoding)
    response.stubs(:body).returns(body)
  end

  describe "when zlib is not available" do
    before(:each) do
      Puppet.features.stubs(:zlib?).returns false

      require 'puppet/network/http/compression'
      class HttpUncompressor
        include Puppet::Network::HTTP::Compression::None
      end

      @uncompressor = HttpUncompressor.new
    end

    it "should have a module function that returns the None underlying module" do
      expect(Puppet::Network::HTTP::Compression.module).to eq(Puppet::Network::HTTP::Compression::None)
    end

    it "should not add any Accept-Encoding header" do
      expect(@uncompressor.add_accept_encoding({})).to eq({})
    end

    it "should not tamper the body" do
      response = stub 'response', :body => data
      expect(@uncompressor.uncompress_body(response)).to eq(data)
    end

    it "should yield an identity uncompressor" do
      response = stub 'response'
      @uncompressor.uncompress(response) { |u|
        expect(u).to be_instance_of(Puppet::Network::HTTP::Compression::IdentityAdapter)
      }
    end
  end

  describe "when zlib is available" do
    require 'puppet/network/http/compression'
    class ActiveUncompressor
      include Puppet::Network::HTTP::Compression::Active
    end

    let(:uncompressor) { ActiveUncompressor.new }

    it "should have a module function that returns the Active underlying module" do
      expect(Puppet::Network::HTTP::Compression.module).to eq(Puppet::Network::HTTP::Compression::Active)
    end

    it "should add an Accept-Encoding header supporting compression" do
      headers = uncompressor.add_accept_encoding({})
      expect(headers).to have_key('accept-encoding')
      expect(headers['accept-encoding']).to match(/gzip/)
      expect(headers['accept-encoding']).to match(/deflate/)
      expect(headers['accept-encoding']).to match(/identity/)
    end

    describe "when uncompressing response body" do
      context "without compression" do
        it "should return untransformed response body with no content-encoding" do
          stubs_response_with(response, nil, data)

          expect(uncompressor.uncompress_body(response)).to eq(data)
        end

        it "should return untransformed response body with 'identity' content-encoding" do
          stubs_response_with(response, 'identity', data)

          expect(uncompressor.uncompress_body(response)).to eq(data)
        end
      end

      context "with 'zlib' content-encoding" do
        it "should use a Zlib inflater" do
          stubs_response_with(response, 'deflate', compressed_zlib)

          expect(uncompressor.uncompress_body(response)).to eq(data)
        end

      end

      context "with 'gzip' content-encoding" do
        it "should use a GzipReader" do
          stubs_response_with(response, 'gzip', compressed_gzip)

          expect(uncompressor.uncompress_body(response)).to eq(data)
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

            uncompressed = uncompressor.uncompress_body(response)
            # By default Zlib::GzipReader decompresses into Encoding.default_external, and we want to ensure our result is BINARY too
            expect(uncompressed.encoding).to eq(Encoding::BINARY)
            expect(uncompressed).to eq("\"foo\xDB\xBF\xE1\x9A\xA0\xF0\xA0\x9C\x8E\"".force_encoding(Encoding::BINARY))
          ensure
            Encoding.default_external = default_external
          end
        end
      end
    end

    describe "when uncompressing by chunk" do
      it "should yield an identity uncompressor with no content-encoding" do
        stubs_response_with(response, nil, data)

        expect { |b|
          uncompressor.uncompress(response).yield_once_with(Puppet::Network::HTTP::Compression::IdentityAdapter, &b)
        }
      end

      it "should yield an identity uncompressor with 'identity' content-encoding" do
        stubs_response_with(response, 'identity', data)

        expect { |b|
          uncompressor.uncompress(response).yield_once_with(Puppet::Network::HTTP::Compression::IdentityAdapter, &b)
        }
      end

      it "should yield a Zlib uncompressor with 'gzip' content-encoding" do
        stubs_response_with(response, 'gzip', compressed_gzip)

        expect { |b|
          uncompressor.uncompress(response).yield_once_with(Puppet::Network::HTTP::Compression::ZlibAdapter, &b)
        }
      end

      it "should yield a Zlib uncompressor with 'deflate' content-encoding" do
        stubs_response_with(response, 'deflate', compressed_zlib)

        expect { |b|
          uncompressor.uncompress(response).yield_once_with(Puppet::Network::HTTP::Compression::ZlibAdapter, &b)
        }
      end

      it "should close the underlying adapter" do
        stubs_response_with(response, 'identity', data)
        adapter = stub_everything 'adapter'
        Puppet::Network::HTTP::Compression::IdentityAdapter.expects(:new).returns(adapter)

        adapter.expects(:close)
        uncompressor.uncompress(response) { |u| }
      end

      it "should close the underlying adapter if the yielded block raises" do
        stubs_response_with(response, 'identity', data)
        adapter = stub_everything 'adapter'
        Puppet::Network::HTTP::Compression::IdentityAdapter.expects(:new).returns(adapter)

        adapter.expects(:close)
        expect {
          uncompressor.uncompress(response) { |u| raise ArgumentError, "whoops" }
        }.to raise_error(ArgumentError, "whoops")
      end
    end

    describe "zlib adapter" do
      it "should initialize the underlying inflater with gzip/zlib header parsing" do
        Zlib::Inflate.expects(:new).with(15+32)

        Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new
      end

      it "should return the given chunk" do
        adapter = Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new

        expect(adapter.uncompress(compressed_zlib)).to eq(data)
      end

      it "should try a 'regular' inflater on Zlib::DataError" do
        inflater = Zlib::Inflate.new(15 + 32)
        inflater.expects(:inflate).raises(Zlib::DataError.new("not a zlib stream"))
        adapter = Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new(inflater)

        expect(adapter.uncompress(compressed_zlib)).to eq(data)
      end

      it "should raise the error the second time" do
        inflater = Zlib::Inflate.new(15 + 32)
        inflater.expects(:inflate).raises(Zlib::DataError.new("not a zlib stream"))
        adapter = Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new(inflater)

        expect { adapter.uncompress("this is not compressed data") }.to raise_error(Zlib::DataError, /incorrect header check/)
      end

      it "should finish and close the stream" do
        inflater = stub 'inflater'
        inflater.expects(:finish)
        inflater.expects(:close)
        adapter = Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new(inflater)

        adapter.close
      end

      it "should close the stream even if finish raises" do
        inflater = stub 'inflater'
        inflater.expects(:finish).raises(Zlib::BufError)
        inflater.expects(:close)

        adapter = Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new(inflater)
        expect {
          adapter.close
        }.to raise_error(Zlib::BufError)
      end
    end
  end
end
