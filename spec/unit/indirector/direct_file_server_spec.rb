require 'spec_helper'

require 'puppet/indirector/direct_file_server'

describe Puppet::Indirector::DirectFileServer do
  before(:each) do
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

  after(:each) do
    Puppet::FileTestModel.indirection.delete
    Puppet.send(:remove_const, :FileTestModel)
  end

  describe "when finding a single file" do
    it "should return nil if the file does not exist" do
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(false)
      expect(indirection.find(path)).to be_nil
    end

    it "should return a Content instance created with the full path to the file if the file exists" do
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
      mycontent = double('content', :collect => nil)
      expect(mycontent).to receive(:collect)
      expect(model).to receive(:new).and_return(mycontent)
      expect(indirection.find(path)).to eq(mycontent)
    end
  end

  describe "when creating the instance for a single found file" do
    let(:data) { double('content', collect: nil) }

    before(:each) do
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
    end

    it "should pass the full path to the instance" do
      expect(model).to receive(:new).with(path, anything).and_return(data)
      indirection.find(path)
    end

    it "should pass the :links setting on to the created Content instance if the file exists and there is a value for :links" do
      expect(model).to receive(:new).and_return(data)
      expect(data).to receive(:links=).with(:manage)

      indirection.find(path, links: :manage)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      expect(model).to receive(:new).and_return(data)
      expect(data).to receive(:checksum_type=).with(:checksum)

      indirection.find(path, checksum_type: :checksum)
    end
  end

  describe "when searching for multiple files" do
    it "should return nil if the file does not exist" do
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(false)
      expect(indirection.search(path)).to be_nil
    end

    it "should pass the original request to :path2instances" do
      expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
      expect(terminus).to receive(:path2instances).with(anything, path)
      indirection.search(path)
    end
  end
end
