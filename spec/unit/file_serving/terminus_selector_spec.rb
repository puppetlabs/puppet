#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/terminus_selector'

describe Puppet::FileServing::TerminusSelector do
  before do
    @object = Object.new
    @object.extend(Puppet::FileServing::TerminusSelector)

    @request = stub 'request', :key => "mymod/myfile", :options => {:node => "whatever"}, :server => nil, :protocol => nil
  end

  describe "when being used to select termini" do
    it "should return :file if the request key is fully qualified" do
      @request.expects(:key).returns File.expand_path('/foo')
      expect(@object.select(@request)).to eq(:file)
    end

    it "should return :file if the URI protocol is set to 'file'" do
      @request.expects(:protocol).returns "file"
      expect(@object.select(@request)).to eq(:file)
    end

    it "should return :http if the URI protocol is set to 'http'" do
      @request.expects(:protocol).returns "http"
      expect(@object.select(@request)).to eq :http
    end

    it "should return :http if the URI protocol is set to 'https'" do
      @request.expects(:protocol).returns "https"
      expect(@object.select(@request)).to eq :http
    end

    it "should fail when a protocol other than :puppet, :http(s) or :file is used" do
      @request.stubs(:protocol).returns "ftp"
      expect { @object.select(@request) }.to raise_error(ArgumentError)
    end

    describe "and the protocol is 'puppet'" do
      before do
        @request.stubs(:protocol).returns "puppet"
      end

      it "should choose :rest when a server is specified" do
        @request.stubs(:protocol).returns "puppet"
        @request.expects(:server).returns "foo"
        expect(@object.select(@request)).to eq(:rest)
      end

      # This is so a given file location works when bootstrapping with no server.
      it "should choose :rest when default_file_terminus is rest" do
        @request.stubs(:protocol).returns "puppet"
        Puppet[:server] = 'localhost'
        expect(@object.select(@request)).to eq(:rest)
      end

      it "should choose :file_server when default_file_terminus is file_server and no server is specified on the request" do
        @request.expects(:protocol).returns "puppet"
        @request.expects(:server).returns nil
        Puppet[:default_file_terminus] = 'file_server'
        expect(@object.select(@request)).to eq(:file_server)
      end
    end
  end
end
