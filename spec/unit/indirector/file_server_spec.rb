require 'spec_helper'

require 'puppet/indirector/file_server'
require 'puppet/file_serving/configuration'

describe Puppet::Indirector::FileServer do
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
    Testing.send(:remove_const, :MyFileServer) if Testing.constants.include?(:MyFileServer)

    @file_server_class = class Testing::MyFileServer < Puppet::Indirector::FileServer
      self
    end

    @file_server = @file_server_class.new

    @uri = "puppet://host/my/local/file"
    @configuration = double('configuration')
    allow(Puppet::FileServing::Configuration).to receive(:configuration).and_return(@configuration)

    @request = Puppet::Indirector::Request.new(:myind, :mymethod, @uri, :environment => "myenv")
  end

  describe "when finding files" do
    before do
      @mount = double('mount', :find => nil)
      @instance = double('instance', :links= => nil, :collect => nil)
    end

    it "should use the configuration to find the mount and relative path" do
      expect(@configuration).to receive(:split_path).with(@request)

      @file_server.find(@request)
    end

    it "should return nil if it cannot find the mount" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([nil, nil])

      expect(@file_server.find(@request)).to be_nil
    end

    it "should use the mount to find the full path" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:find).with("rel/path", anything)

      @file_server.find(@request)
    end

    it "should pass the request when finding a file" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:find).with(anything, @request)

      @file_server.find(@request)
    end

    it "should return nil if it cannot find a full path" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:find).with("rel/path", anything).and_return(nil)

      expect(@file_server.find(@request)).to be_nil
    end

    it "should create an instance with the found path" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:find).with("rel/path", anything).and_return("/my/file")

      expect(@model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(@instance)

      expect(@file_server.find(@request)).to equal(@instance)
    end

    it "should set 'links' on the instance if it is set in the request options" do
      @request.options[:links] = true
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:find).with("rel/path", anything).and_return("/my/file")

      expect(@model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(@instance)

      expect(@instance).to receive(:links=).with(true)

      expect(@file_server.find(@request)).to equal(@instance)
    end

    it "should collect the instance" do
      @request.options[:links] = true
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:find).with("rel/path", anything).and_return("/my/file")

      expect(@model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(@instance)

      expect(@instance).to receive(:collect)

      expect(@file_server.find(@request)).to equal(@instance)
    end
  end

  describe "when searching for instances" do
    before do
      @mount = double('mount', :search => nil)
      @instance = double('instance', :links= => nil, :collect => nil)
    end

    it "should use the configuration to search the mount and relative path" do
      expect(@configuration).to receive(:split_path).with(@request)

      @file_server.search(@request)
    end

    it "should return nil if it cannot search the mount" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([nil, nil])

      expect(@file_server.search(@request)).to be_nil
    end

    it "should use the mount to search for the full paths" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything)

      @file_server.search(@request)
    end

    it "should pass the request" do
      allow(@configuration).to receive(:split_path).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with(anything, @request)

      @file_server.search(@request)
    end

    it "should return nil if searching does not find any full paths" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything).and_return(nil)

      expect(@file_server.search(@request)).to be_nil
    end

    it "should create a fileset with each returned path and merge them" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything).and_return(%w{/one /two})

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      one = double('fileset_one')
      expect(Puppet::FileServing::Fileset).to receive(:new).with("/one", @request).and_return(one)
      two = double('fileset_two')
      expect(Puppet::FileServing::Fileset).to receive(:new).with("/two", @request).and_return(two)

      expect(Puppet::FileServing::Fileset).to receive(:merge).with(one, two).and_return([])

      @file_server.search(@request)
    end

    it "should create an instance with each path resulting from the merger of the filesets" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one", "two" => "/two")

      one = double('one', :collect => nil)
      expect(@model).to receive(:new).with("/one", :relative_path => "one").and_return(one)

      two = double('two', :collect => nil)
      expect(@model).to receive(:new).with("/two", :relative_path => "two").and_return(two)

      # order can't be guaranteed
      result = @file_server.search(@request)
      expect(result).to be_include(one)
      expect(result).to be_include(two)
      expect(result.length).to eq(2)
    end

    it "should set 'links' on the instances if it is set in the request options" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one")

      one = double('one', :collect => nil)
      expect(@model).to receive(:new).with("/one", :relative_path => "one").and_return(one)
      expect(one).to receive(:links=).with(true)

      @request.options[:links] = true

      @file_server.search(@request)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one")

      one = double('one', :collect => nil)
      expect(@model).to receive(:new).with("/one", :relative_path => "one").and_return(one)

      expect(one).to receive(:checksum_type=).with(:checksum)
      @request.options[:checksum_type] = :checksum

      @file_server.search(@request)
    end

    it "should collect the instances" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])

      expect(@mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one")

      one = double('one')
      expect(@model).to receive(:new).with("/one", :relative_path => "one").and_return(one)
      expect(one).to receive(:collect)

      @file_server.search(@request)
    end
  end

  describe "when checking authorization" do
    before do
      @request.method = :find

      @mount = double('mount')
      allow(@configuration).to receive(:split_path).with(@request).and_return([@mount, "rel/path"])
      allow(@request).to receive(:node).and_return("mynode")
      allow(@request).to receive(:ip).and_return("myip")
      allow(@mount).to receive(:name).and_return("myname")
      allow(@mount).to receive(:allowed?).with("mynode", "myip").and_return("something")
      allow(@mount).to receive(:empty?)
      allow(@mount).to receive(:globalallow?)
    end

    it "should return false when destroying" do
      @request.method = :destroy
      expect(@file_server).not_to be_authorized(@request)
    end

    it "should return false when saving" do
      @request.method = :save
      expect(@file_server).not_to be_authorized(@request)
    end

    it "should use the configuration to find the mount and relative path" do
      expect(@configuration).to receive(:split_path).with(@request)

      @file_server.authorized?(@request)
    end

    it "should return false if it cannot find the mount" do
      expect(@configuration).to receive(:split_path).with(@request).and_return([nil, nil])

      expect(@file_server).not_to be_authorized(@request)
    end

    it "should return true when no auth directives are defined for the mount point" do
      allow(@mount).to receive(:empty?).and_return(true)
      allow(@mount).to receive(:globalallow?).and_return(nil)
      expect(@file_server).to be_authorized(@request)
    end

    it "should return true when a global allow directive is defined for the mount point" do
      allow(@mount).to receive(:empty?).and_return(false)
      allow(@mount).to receive(:globalallow?).and_return(true)
      expect(@file_server).to be_authorized(@request)
    end

    it "should return false when a non-global allow directive is defined for the mount point" do
      allow(@mount).to receive(:empty?).and_return(false)
      allow(@mount).to receive(:globalallow?).and_return(false)
      expect(@file_server).not_to be_authorized(@request)
    end
  end
end
