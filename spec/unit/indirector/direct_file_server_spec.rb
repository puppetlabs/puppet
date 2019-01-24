require 'spec_helper'

require 'puppet/indirector/direct_file_server'

describe Puppet::Indirector::DirectFileServer do
  before(:each) do
    allow(Puppet::Indirector::Terminus).to receive(:register_terminus_class)
    @model = double('model')
    @indirection = double('indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model)
    allow(Puppet::Indirector::Indirection).to receive(:instance).and_return(@indirection)

    module Testing; end

    # The Indirector does a lot of class-level caching of things, and indirections register themselves
    # whenever they're created (at include time), which makes working with them in tests _very_ annoying.
    # We're effectively undefining the test class if it exists from a previous test so that we can
    # re-register the new one as any mocks/stubs that existed on the old one from a previous test will no
    # longer be valid, and will cause rspec-mocks to (rightfully) blow up.
    Testing.send(:remove_const, :Mytype) if Testing.constants.include?(:Mytype)

    @direct_file_class = class Testing::Mytype < Puppet::Indirector::DirectFileServer
      self
    end

    @server = @direct_file_class.new

    @path = File.expand_path('/my/local')
    @uri = Puppet::Util.path_to_uri(@path).to_s

    @request = Puppet::Indirector::Request.new(:mytype, :find, @uri, nil)
  end

  describe Puppet::Indirector::DirectFileServer, "when finding a single file" do

    it "should return nil if the file does not exist" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(false)
      expect(@server.find(@request)).to be_nil
    end

    it "should return a Content instance created with the full path to the file if the file exists" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
      mycontent = double('content', :collect => nil)
      expect(mycontent).to receive(:collect)
      expect(@model).to receive(:new).and_return(mycontent)
      expect(@server.find(@request)).to eq(mycontent)
    end
  end

  describe Puppet::Indirector::DirectFileServer, "when creating the instance for a single found file" do
    before do
      @data = double('content')
      allow(@data).to receive(:collect)
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
    end

    it "should pass the full path to the instance" do
      expect(@model).to receive(:new).with(@path, anything).and_return(@data)
      @server.find(@request)
    end

    it "should pass the :links setting on to the created Content instance if the file exists and there is a value for :links" do
      expect(@model).to receive(:new).and_return(@data)
      expect(@data).to receive(:links=).with(:manage)

      allow(@request).to receive(:options).and_return(:links => :manage)
      @server.find(@request)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      expect(@model).to receive(:new).and_return(@data)
      expect(@data).to receive(:checksum_type=).with(:checksum)

      allow(@request).to receive(:options).and_return(:checksum_type => :checksum)
      @server.find(@request)
    end
  end

  describe Puppet::Indirector::DirectFileServer, "when searching for multiple files" do
    it "should return nil if the file does not exist" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(false)
      expect(@server.find(@request)).to be_nil
    end

    it "should use :path2instances from the terminus_helper to return instances if the file exists" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
      expect(@server).to receive(:path2instances)
      @server.search(@request)
    end

    it "should pass the original request to :path2instances" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
      expect(@server).to receive(:path2instances).with(@request, @path)
      @server.search(@request)
    end
  end
end
