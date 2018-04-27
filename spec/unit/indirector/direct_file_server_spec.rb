#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/direct_file_server'

describe Puppet::Indirector::DirectFileServer do
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

    class Puppet::FileTestModel::DirectFileServer < Puppet::Indirector::DirectFileServer
    end

    Puppet::FileTestModel.indirection.terminus_class = :direct_file_server
  end

  let(:path) { File.expand_path('/my/local') }
  let(:terminus) { Puppet::FileTestModel.indirection.terminus(:direct_file_server) }
  let(:indirection) { Puppet::FileTestModel.indirection }
  let(:model) { Puppet::FileTestModel }

  after(:all) do
    Puppet::FileTestModel.indirection.delete
    Puppet.send(:remove_const, :FileTestModel)
  end

  describe "when finding a single file" do
    it "should return nil if the file does not exist" do
      Puppet::FileSystem.expects(:exist?).with(path).returns(false)
      expect(indirection.find(path)).to be_nil
    end

    it "should return a Content instance created with the full path to the file if the file exists" do
      Puppet::FileSystem.expects(:exist?).with(path).returns(true)
      mycontent = stub 'content', :collect => nil
      mycontent.expects(:collect)
      model.expects(:new).returns(mycontent)
      expect(indirection.find(path)).to eq(mycontent)
    end
  end

  describe "when creating the instance for a single found file" do
    let(:data) { stub('content', collect: nil) }

    before(:each) do
      Puppet::FileSystem.expects(:exist?).with(path).returns(true)
    end

    it "should pass the full path to the instance" do
      model.expects(:new).with { |key, options| key == path }.returns(data)
      indirection.find(path)
    end

    it "should pass the :links setting on to the created Content instance if the file exists and there is a value for :links" do
      model.expects(:new).returns(data)
      data.expects(:links=).with(:manage)

      indirection.find(path, links: :manage)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      model.expects(:new).returns(data)
      data.expects(:checksum_type=).with(:checksum)

      indirection.find(path, checksum_type: :checksum)
    end
  end

  describe "when searching for multiple files" do
    it "should return nil if the file does not exist" do
      Puppet::FileSystem.expects(:exist?).with(path).returns(false)
      expect(indirection.search(path)).to be_nil
    end

    it "should pass the original request to :path2instances" do
      Puppet::FileSystem.expects(:exist?).with(path).returns(true)
      terminus.expects(:path2instances).with(anything, path)
      indirection.search(path)
    end
  end
end
