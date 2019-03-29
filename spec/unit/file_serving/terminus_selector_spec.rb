require 'spec_helper'

require 'puppet/file_serving/terminus_selector'

describe Puppet::FileServing::TerminusSelector do
  before do
    @object = Object.new
    @object.extend(Puppet::FileServing::TerminusSelector)

    @request = double('request', :key => "mymod/myfile", :options => {:node => "whatever"}, :server => nil, :protocol => nil)
  end

  describe "when being used to select termini" do
    it "should return :file if the request key is fully qualified" do
      expect(@request).to receive(:key).and_return(File.expand_path('/foo'))
      expect(@object.select(@request)).to eq(:file)
    end

    it "should return :file if the URI protocol is set to 'file'" do
      expect(@request).to receive(:protocol).and_return("file")
      expect(@object.select(@request)).to eq(:file)
    end

    it "should return :http if the URI protocol is set to 'http'" do
      expect(@request).to receive(:protocol).and_return("http")
      expect(@object.select(@request)).to eq :http
    end

    it "should return :http if the URI protocol is set to 'https'" do
      expect(@request).to receive(:protocol).and_return("https")
      expect(@object.select(@request)).to eq :http
    end

    it "should fail when a protocol other than :puppet, :http(s) or :file is used" do
      allow(@request).to receive(:protocol).and_return("ftp")
      expect { @object.select(@request) }.to raise_error(ArgumentError)
    end

    describe "and the protocol is 'puppet'" do
      before do
        allow(@request).to receive(:protocol).and_return("puppet")
      end

      it "should choose :rest when a server is specified" do
        allow(@request).to receive(:protocol).and_return("puppet")
        expect(@request).to receive(:server).and_return("foo")
        expect(@object.select(@request)).to eq(:rest)
      end

      # This is so a given file location works when bootstrapping with no server.
      it "should choose :rest when default_file_terminus is rest" do
        allow(@request).to receive(:protocol).and_return("puppet")
        Puppet[:server] = 'localhost'
        expect(@object.select(@request)).to eq(:rest)
      end

      it "should choose :file_server when default_file_terminus is file_server and no server is specified on the request" do
        expect(@request).to receive(:protocol).and_return("puppet")
        expect(@request).to receive(:server).and_return(nil)
        Puppet[:default_file_terminus] = 'file_server'
        expect(@object.select(@request)).to eq(:file_server)
      end
    end
  end
end
