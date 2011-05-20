#!/usr/bin/env rspec
require 'spec_helper'

describe "http compression" do

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
      Puppet::Network::HTTP::Compression.module.should == Puppet::Network::HTTP::Compression::None
    end

    it "should not add any Accept-Encoding header" do
      @uncompressor.add_accept_encoding({}).should == {}
    end

    it "should not tamper the body" do
      response = stub 'response', :body => "data"
      @uncompressor.uncompress_body(response).should == "data"
    end

    it "should yield an identity uncompressor" do
      response = stub 'response'
      @uncompressor.uncompress(response) { |u|
        u.should be_instance_of(Puppet::Network::HTTP::Compression::IdentityAdapter)
      }
    end
  end

  describe "when zlib is available", :if => Puppet.features.zlib? do
    before(:each) do
      Puppet.features.stubs(:zlib?).returns true

      require 'puppet/network/http/compression'
      class HttpUncompressor
        include Puppet::Network::HTTP::Compression::Active
      end

      @uncompressor = HttpUncompressor.new
    end

    it "should have a module function that returns the Active underlying module" do
      Puppet::Network::HTTP::Compression.module.should == Puppet::Network::HTTP::Compression::Active
    end

    it "should add an Accept-Encoding header when http compression is available" do
      Puppet.settings.expects(:[]).with(:http_compression).returns(true)
      headers = @uncompressor.add_accept_encoding({})
      headers.should have_key('accept-encoding')
      headers['accept-encoding'].should =~ /gzip/
      headers['accept-encoding'].should =~ /deflate/
      headers['accept-encoding'].should =~ /identity/
    end

    it "should not add Accept-Encoding header if http compression is not available" do
      Puppet.settings.stubs(:[]).with(:http_compression).returns(false)
      @uncompressor.add_accept_encoding({}).should == {}
    end

    describe "when uncompressing response body" do
      before do
        @response = stub 'response'
        @response.stubs(:[]).with('content-encoding')
        @response.stubs(:body).returns("mydata")
      end

      it "should return untransformed response body with no content-encoding" do
        @uncompressor.uncompress_body(@response).should == "mydata"
      end

      it "should return untransformed response body with 'identity' content-encoding" do
        @response.stubs(:[]).with('content-encoding').returns('identity')
        @uncompressor.uncompress_body(@response).should == "mydata"
      end

      it "should use a Zlib inflater with 'deflate' content-encoding" do
        @response.stubs(:[]).with('content-encoding').returns('deflate')

        inflater = stub 'inflater'
        Zlib::Inflate.expects(:new).returns(inflater)
        inflater.expects(:inflate).with("mydata").returns "uncompresseddata"

        @uncompressor.uncompress_body(@response).should == "uncompresseddata"
      end

      it "should use a GzipReader with 'gzip' content-encoding" do
        @response.stubs(:[]).with('content-encoding').returns('gzip')

        io = stub 'io'
        StringIO.expects(:new).with("mydata").returns io

        reader = stub 'gzip reader'
        Zlib::GzipReader.expects(:new).with(io).returns(reader)
        reader.expects(:read).returns "uncompresseddata"

        @uncompressor.uncompress_body(@response).should == "uncompresseddata"
      end
    end

    describe "when uncompressing by chunk" do
      before do
        @response = stub 'response'
        @response.stubs(:[]).with('content-encoding')

        @inflater = stub_everything 'inflater'
        Zlib::Inflate.stubs(:new).returns(@inflater)
      end

      it "should yield an identity uncompressor with no content-encoding" do
        @uncompressor.uncompress(@response) { |u|
          u.should be_instance_of(Puppet::Network::HTTP::Compression::IdentityAdapter)
        }
      end

      it "should yield an identity uncompressor with 'identity' content-encoding" do
        @response.stubs(:[]).with('content-encoding').returns 'identity'
        @uncompressor.uncompress(@response) { |u|
          u.should be_instance_of(Puppet::Network::HTTP::Compression::IdentityAdapter)
        }
      end

      %w{gzip deflate}.each do |c|
        it "should yield a Zlib uncompressor with '#{c}' content-encoding" do
          @response.stubs(:[]).with('content-encoding').returns c
          @uncompressor.uncompress(@response) { |u|
            u.should be_instance_of(Puppet::Network::HTTP::Compression::Active::ZlibAdapter)
          }
        end
      end

      it "should close the underlying adapter" do
        adapter = stub_everything 'adapter'
        Puppet::Network::HTTP::Compression::IdentityAdapter.expects(:new).returns(adapter)

        adapter.expects(:close)
        @uncompressor.uncompress(@response) { |u| }
      end
    end

    describe "zlib adapter" do
      before do
        @inflater = stub_everything 'inflater'
        Zlib::Inflate.stubs(:new).returns(@inflater)
        @adapter = Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new
      end

      it "should initialize the underlying inflater with gzip/zlib header parsing" do
        Zlib::Inflate.expects(:new).with(15+32)
        Puppet::Network::HTTP::Compression::Active::ZlibAdapter.new
      end

      it "should inflate the given chunk" do
        @inflater.expects(:inflate).with("chunk")
        @adapter.uncompress("chunk")
      end

      it "should return the inflated chunk" do
        @inflater.stubs(:inflate).with("chunk").returns("uncompressed")
        @adapter.uncompress("chunk").should == "uncompressed"
      end

      it "should try a 'regular' inflater on Zlib::DataError" do
        @inflater.expects(:inflate).raises(Zlib::DataError.new("not a zlib stream"))
        inflater = stub_everything 'inflater2'
        inflater.expects(:inflate).with("chunk").returns("uncompressed")
        Zlib::Inflate.expects(:new).with.returns(inflater)
        @adapter.uncompress("chunk")
      end

      it "should raise the error the second time" do
        @inflater.stubs(:inflate).raises(Zlib::DataError.new("not a zlib stream"))
        Zlib::Inflate.expects(:new).with.returns(@inflater)
        lambda { @adapter.uncompress("chunk") }.should raise_error
      end

      it "should finish the stream on close" do
        @inflater.expects(:finish)
        @adapter.close
      end

      it "should close the stream on close" do
        @inflater.expects(:close)
        @adapter.close
      end
    end
  end
end
