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
  let(:configuration) { double('configuration') }

  after(:all) do
    Puppet::FileTestModel.indirection.delete
    Puppet.send(:remove_const, :FileTestModel)
  end

  before(:each)do
    allow(Puppet::FileServing::Configuration).to receive(:configuration).and_return(configuration)
  end

  describe "when finding files" do
    let(:mount) { double('mount', find: nil) }
    let(:instance) { double('instance', :links= => nil, :collect => nil) }

    it "should use the configuration to find the mount and relative path" do
      expect(configuration).to receive(:split_path) do |args|
        expect(args.uri).to eq(uri)
        nil
      end

      indirection.find(uri)
    end

    it "should return nil if it cannot find the mount" do
      expect(configuration).to receive(:split_path).and_return([nil, nil])

      expect(indirection.find(uri)).to be_nil
    end

    it "should use the mount to find the full path" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:find).with("rel/path", anything)

      indirection.find(uri)
    end

    it "should pass the request when finding a file" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:find) { |_, request| expect(request.uri).to eq(uri) }.and_return(nil)

      indirection.find(uri)
    end

    it "should return nil if it cannot find a full path" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:find).with("rel/path", anything)

      expect(indirection.find(uri)).to be_nil
    end

    it "should create an instance with the found path" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:find).with("rel/path", anything).and_return("/my/file")

      expect(model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(instance)

      expect(indirection.find(uri)).to equal(instance)
    end

    it "should set 'links' on the instance if it is set in the request options" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:find).with("rel/path", anything).and_return("/my/file")

      expect(model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(instance)

      expect(instance).to receive(:links=).with(true)

      expect(indirection.find(uri, links: true)).to equal(instance)
    end

    it "should collect the instance" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:find).with("rel/path", anything).and_return("/my/file")

      expect(model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(instance)

      expect(instance).to receive(:collect)

      expect(indirection.find(uri, links: true)).to equal(instance)
    end
  end

  describe "when searching for instances" do
    let(:mount) { double('mount', find: nil) }

    it "should use the configuration to search the mount and relative path" do
      expect(configuration).to receive(:split_path) do |args|
        expect(args.uri).to eq(uri)
      end.and_return([nil, nil])

      indirection.search(uri)
    end

    it "should return nil if it cannot search the mount" do
      expect(configuration).to receive(:split_path).and_return([nil, nil])

      expect(indirection.search(uri)).to be_nil
    end

    it "should use the mount to search for the full paths" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything)

      indirection.search(uri)
    end

    it "should pass the request" do
      allow(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search) { |_, request| expect(request.uri).to eq(uri) }.and_return(nil)

      indirection.search(uri)
    end

    it "should return nil if searching does not find any full paths" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything).and_return(nil)

      expect(indirection.search(uri)).to be_nil
    end

    it "should create a fileset with each returned path and merge them" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything).and_return(%w{/one /two})

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      one = double('fileset_one')
      expect(Puppet::FileServing::Fileset).to receive(:new).with("/one", anything).and_return(one)
      two = double('fileset_two')
      expect(Puppet::FileServing::Fileset).to receive(:new).with("/two", anything).and_return(two)

      expect(Puppet::FileServing::Fileset).to receive(:merge).with(one, two).and_return([])

      indirection.search(uri)
    end

    it "should create an instance with each path resulting from the merger of the filesets" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one", "two" => "/two")

      one = double('one', :collect => nil)
      expect(model).to receive(:new).with("/one", {:relative_path => "one"}).and_return(one)

      two = double('two', :collect => nil)
      expect(model).to receive(:new).with("/two", {:relative_path => "two"}).and_return(two)

      # order can't be guaranteed
      result = indirection.search(uri)
      expect(result).to be_include(one)
      expect(result).to be_include(two)
      expect(result.length).to eq(2)
    end

    it "should set 'links' on the instances if it is set in the request options" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one")

      one = double('one', :collect => nil)
      expect(model).to receive(:new).with("/one", {:relative_path => "one"}).and_return(one)
      expect(one).to receive(:links=).with(true)

      indirection.search(uri, links: true)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one")

      one = double('one', :collect => nil)
      expect(model).to receive(:new).with("/one", {:relative_path => "one"}).and_return(one)

      expect(one).to receive(:checksum_type=).with(:checksum)

      indirection.search(uri, checksum_type: :checksum)
    end

    it "should collect the instances" do
      expect(configuration).to receive(:split_path).and_return([mount, "rel/path"])

      expect(mount).to receive(:search).with("rel/path", anything).and_return([])

      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)

      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return("one" => "/one")

      one = double('one')
      expect(model).to receive(:new).with("/one", {:relative_path => "one"}).and_return(one)
      expect(one).to receive(:collect)

      indirection.search(uri)
    end
  end

  describe "when checking authorization" do
    let(:mount) { double('mount') }
    let(:request) { Puppet::Indirector::Request.new(:myind, :mymethod, uri, :environment => "myenv") }

    before(:each) do
      request.method = :find

      allow(configuration).to receive(:split_path).and_return([mount, "rel/path"])
      allow(request).to receive(:node).and_return("mynode")
      allow(request).to receive(:ip).and_return("myip")
      allow(mount).to receive(:name).and_return("myname")
      allow(mount).to receive(:allowed?).with("mynode", "myip").and_return("something")
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
      expect(configuration).to receive(:split_path).with(request)

      terminus.authorized?(request)
    end

    it "should return false if it cannot find the mount" do
      expect(configuration).to receive(:split_path).and_return([nil, nil])

      expect(terminus).not_to be_authorized(request)
    end

    it "should return true when no auth directives are defined for the mount point" do
      expect(terminus).to be_authorized(request)
    end
  end
end
