#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_server'
require 'puppet/file_serving/configuration'

describe Puppet::Indirector::FileServer do

  before :all do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @file_server_class = class Testing::MyFileServer < Puppet::Indirector::FileServer
      self
    end
  end

  before :each do
    @file_server = @file_server_class.new

    @uri = "puppet://host/my/local/file"
    @configuration = mock 'configuration'
    Puppet::FileServing::Configuration.stubs(:configuration).returns(@configuration)

    @request = Puppet::Indirector::Request.new(:myind, :mymethod, @uri, :environment => "myenv")
  end

  describe "when finding files" do
    before do
      @mount = stub 'mount', :find => nil
      @instance = stub('instance', :links= => nil, :collect => nil)
    end

    it "should use the configuration to find the mount and relative path" do
      @configuration.expects(:split_path).with(@request)

      @file_server.find(@request)
    end

    it "should return nil if it cannot find the mount" do
      @configuration.expects(:split_path).with(@request).returns(nil, nil)

      expect(@file_server.find(@request)).to be_nil
    end

    it "should use the mount to find the full path" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:find).with { |key, request| key == "rel/path" }

      @file_server.find(@request)
    end

    it "should pass the request when finding a file" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:find).with { |key, request| request == @request }

      @file_server.find(@request)
    end

    it "should return nil if it cannot find a full path" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:find).with { |key, request| key == "rel/path" }.returns nil

      expect(@file_server.find(@request)).to be_nil
    end

    it "should create an instance with the found path" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:find).with { |key, request| key == "rel/path" }.returns "/my/file"

      @model.expects(:new).with("/my/file", {:relative_path => nil}).returns @instance

      expect(@file_server.find(@request)).to equal(@instance)
    end

    it "should set 'links' on the instance if it is set in the request options" do
      @request.options[:links] = true
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:find).with { |key, request| key == "rel/path" }.returns "/my/file"

      @model.expects(:new).with("/my/file", {:relative_path => nil}).returns @instance

      @instance.expects(:links=).with(true)

      expect(@file_server.find(@request)).to equal(@instance)
    end

    it "should collect the instance" do
      @request.options[:links] = true
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:find).with { |key, request| key == "rel/path" }.returns "/my/file"

      @model.expects(:new).with("/my/file", {:relative_path => nil}).returns @instance

      @instance.expects(:collect)

      expect(@file_server.find(@request)).to equal(@instance)
    end
  end

  describe "when searching for instances" do
    before do
      @mount = stub 'mount', :search => nil
      @instance = stub('instance', :links= => nil, :collect => nil)
    end

    it "should use the configuration to search the mount and relative path" do
      @configuration.expects(:split_path).with(@request)

      @file_server.search(@request)
    end

    it "should return nil if it cannot search the mount" do
      @configuration.expects(:split_path).with(@request).returns(nil, nil)

      expect(@file_server.search(@request)).to be_nil
    end

    it "should use the mount to search for the full paths" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| key == "rel/path" }

      @file_server.search(@request)
    end

    it "should pass the request" do
      @configuration.stubs(:split_path).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| request == @request }

      @file_server.search(@request)
    end

    it "should return nil if searching does not find any full paths" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| key == "rel/path" }.returns nil

      expect(@file_server.search(@request)).to be_nil
    end

    it "should create a fileset with each returned path and merge them" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| key == "rel/path" }.returns %w{/one /two}

      Puppet::FileSystem.stubs(:exist?).returns true

      one = mock 'fileset_one'
      Puppet::FileServing::Fileset.expects(:new).with("/one", @request).returns(one)
      two = mock 'fileset_two'
      Puppet::FileServing::Fileset.expects(:new).with("/two", @request).returns(two)

      Puppet::FileServing::Fileset.expects(:merge).with(one, two).returns []

      @file_server.search(@request)
    end

    it "should create an instance with each path resulting from the merger of the filesets" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one", "two" => "/two")

      one = stub 'one', :collect => nil
      @model.expects(:new).with("/one", :relative_path => "one").returns one

      two = stub 'two', :collect => nil
      @model.expects(:new).with("/two", :relative_path => "two").returns two

      # order can't be guaranteed
      result = @file_server.search(@request)
      expect(result).to be_include(one)
      expect(result).to be_include(two)
      expect(result.length).to eq(2)
    end

    it "should set 'links' on the instances if it is set in the request options" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one")

      one = stub 'one', :collect => nil
      @model.expects(:new).with("/one", :relative_path => "one").returns one
      one.expects(:links=).with true

      @request.options[:links] = true

      @file_server.search(@request)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, request| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one")

      one = stub 'one', :collect => nil
      @model.expects(:new).with("/one", :relative_path => "one").returns one

      one.expects(:checksum_type=).with :checksum
      @request.options[:checksum_type] = :checksum

      @file_server.search(@request)
    end

    it "should collect the instances" do
      @configuration.expects(:split_path).with(@request).returns([@mount, "rel/path"])

      @mount.expects(:search).with { |key, options| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one")

      one = mock 'one'
      @model.expects(:new).with("/one", :relative_path => "one").returns one
      one.expects(:collect)

      @file_server.search(@request)
    end
  end

  describe "when checking authorization" do
    before do
      @request.method = :find

      @mount = stub 'mount'
      @configuration.stubs(:split_path).with(@request).returns([@mount, "rel/path"])
      @request.stubs(:node).returns("mynode")
      @request.stubs(:ip).returns("myip")
      @mount.stubs(:allowed?).with("mynode", "myip").returns "something"
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
      @configuration.expects(:split_path).with(@request)

      @file_server.authorized?(@request)
    end

    it "should return false if it cannot find the mount" do
      @configuration.expects(:split_path).with(@request).returns(nil, nil)

      expect(@file_server).not_to be_authorized(@request)
    end

    it "should return the results of asking the mount whether the node and IP are authorized" do
      expect(@file_server.authorized?(@request)).to eq("something")
    end
  end
end
