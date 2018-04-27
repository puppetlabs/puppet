#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_server'
require 'puppet/file_serving/configuration'

describe Puppet::Indirector::FileServer do
  before :all do
    class Puppet::FileTestModel
      extend Puppet::Indirector
      indirects :file_test_model
      attr_accessor :path
      def initialize(path = '/', options = {})
        @path = path
        @options = options
      end
    end

    class Puppet::FileTestModel::FileServer < Puppet::Indirector::FileServer
    end

    Puppet::FileTestModel.indirection.terminus_class = :file_server
  end

  let(:path) { File.expand_path('/my/local') }
  let(:terminus) { Puppet::FileTestModel.indirection.terminus(:file_server) }
  let(:indirection) { Puppet::FileTestModel.indirection }
  let(:model) { Puppet::FileTestModel }
  let(:uri) { "puppet://host/my/local/file" }
  let(:configuration) { mock 'configuration' }

  after(:all) do
    Puppet::FileTestModel.indirection.delete
    Puppet.send(:remove_const, :FileTestModel)
  end

  before(:each)do
    Puppet::FileServing::Configuration.stubs(:configuration).returns(configuration)
  end

  describe "when finding files" do
    let(:mount) { stub('mount', find: nil) }
    let(:instance) { stub('instance', :links= => nil, :collect => nil) }

    it "should use the configuration to find the mount and relative path" do
      configuration.expects(:split_path).with do |args|
        args.uri == uri
      end

      indirection.find(uri)
    end

    it "should return nil if it cannot find the mount" do
      configuration.expects(:split_path).returns(nil, nil)

      expect(indirection.find(uri)).to be_nil
    end

    it "should use the mount to find the full path" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:find).with { |key, request| key == "rel/path" }

      indirection.find(uri)
    end

    it "should pass the request when finding a file" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:find).with { |_, request| request.uri == uri }

      indirection.find(uri)
    end

    it "should return nil if it cannot find a full path" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:find).with { |key, request| key == "rel/path" }.returns nil

      expect(indirection.find(uri)).to be_nil
    end

    it "should create an instance with the found path" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:find).with { |key, request| key == "rel/path" }.returns "/my/file"

      model.expects(:new).with("/my/file", {:relative_path => nil}).returns instance

      expect(indirection.find(uri)).to equal(instance)
    end

    it "should set 'links' on the instance if it is set in the request options" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:find).with { |key, request| key == "rel/path" }.returns "/my/file"

      model.expects(:new).with("/my/file", {:relative_path => nil}).returns instance

      instance.expects(:links=).with(true)

      expect(indirection.find(uri, links: true)).to equal(instance)
    end

    it "should collect the instance" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:find).with { |key, request| key == "rel/path" }.returns "/my/file"

      model.expects(:new).with("/my/file", {:relative_path => nil}).returns instance

      instance.expects(:collect)

      expect(indirection.find(uri, links: true)).to equal(instance)
    end
  end

  describe "when searching for instances" do
    let(:mount) { stub('mount', find: nil) }

    it "should use the configuration to search the mount and relative path" do
      configuration.expects(:split_path).with do |args|
        args.uri == uri
      end

      indirection.search(uri)
    end

    it "should return nil if it cannot search the mount" do
      configuration.expects(:split_path).returns(nil, nil)

      expect(indirection.search(uri)).to be_nil
    end

    it "should use the mount to search for the full paths" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, request| key == "rel/path" }

      indirection.search(uri)
    end

    it "should pass the request" do
      configuration.stubs(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |_, request| request.uri == uri }

      indirection.search(uri)
    end

    it "should return nil if searching does not find any full paths" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, request| key == "rel/path" }.returns nil

      expect(indirection.search(uri)).to be_nil
    end

    it "should create a fileset with each returned path and merge them" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, request| key == "rel/path" }.returns %w{/one /two}

      Puppet::FileSystem.stubs(:exist?).returns true

      one = mock 'fileset_one'
      Puppet::FileServing::Fileset.expects(:new).with("/one", anything).returns(one)
      two = mock 'fileset_two'
      Puppet::FileServing::Fileset.expects(:new).with("/two", anything).returns(two)

      Puppet::FileServing::Fileset.expects(:merge).with(one, two).returns []

      indirection.search(uri)
    end

    it "should create an instance with each path resulting from the merger of the filesets" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, request| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one", "two" => "/two")

      one = stub 'one', :collect => nil
      model.expects(:new).with("/one", :relative_path => "one").returns one

      two = stub 'two', :collect => nil
      model.expects(:new).with("/two", :relative_path => "two").returns two

      # order can't be guaranteed
      result = indirection.search(uri)
      expect(result).to be_include(one)
      expect(result).to be_include(two)
      expect(result.length).to eq(2)
    end

    it "should set 'links' on the instances if it is set in the request options" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, request| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one")

      one = stub 'one', :collect => nil
      model.expects(:new).with("/one", :relative_path => "one").returns one
      one.expects(:links=).with true

      indirection.search(uri, links: true)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, request| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one")

      one = stub 'one', :collect => nil
      model.expects(:new).with("/one", :relative_path => "one").returns one

      one.expects(:checksum_type=).with :checksum

      indirection.search(uri, checksum_type: :checksum)
    end

    it "should collect the instances" do
      configuration.expects(:split_path).returns([mount, "rel/path"])

      mount.expects(:search).with { |key, options| key == "rel/path" }.returns []

      Puppet::FileSystem.stubs(:exist?).returns true

      Puppet::FileServing::Fileset.expects(:merge).returns("one" => "/one")

      one = mock 'one'
      model.expects(:new).with("/one", :relative_path => "one").returns one
      one.expects(:collect)

      indirection.search(uri)
    end
  end

  describe "when checking authorization" do
    let(:mount) { stub('mount') }
    let(:request) { Puppet::Indirector::Request.new(:myind, :mymethod, uri, :environment => "myenv") }

    before(:each) do
      request.method = :find

      configuration.stubs(:split_path).returns([mount, "rel/path"])
      request.stubs(:node).returns("mynode")
      request.stubs(:ip).returns("myip")
      mount.stubs(:name).returns "myname"
      mount.stubs(:allowed?).with("mynode", "myip").returns "something"
    end

    it "should return false when destroying" do
      request.method = :destroy
      expect(terminus).not_to be_authorized(request)
    end

    it "should return false when saving" do
      request.method = :save
      expect(terminus).not_to be_authorized(request)
    end

    it "should use the configuration to find the mount and relative path" do
      configuration.expects(:split_path).with(request)

      terminus.authorized?(request)
    end

    it "should return false if it cannot find the mount" do
      configuration.expects(:split_path).returns(nil, nil)

      expect(terminus).not_to be_authorized(request)
    end

    it "should return true when no auth directives are defined for the mount point" do
      mount.stubs(:empty?).returns true
      mount.stubs(:globalallow?).returns nil
      expect(terminus).to be_authorized(request)
    end

    it "should return true when a global allow directive is defined for the mount point" do
      mount.stubs(:empty?).returns false
      mount.stubs(:globalallow?).returns true
      expect(terminus).to be_authorized(request)
    end

    it "should return false when a non-global allow directive is defined for the mount point" do
      mount.stubs(:empty?).returns false
      mount.stubs(:globalallow?).returns false
      expect(terminus).not_to be_authorized(request)
    end
  end
end
