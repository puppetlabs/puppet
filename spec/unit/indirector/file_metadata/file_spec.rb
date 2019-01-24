require 'spec_helper'

require 'puppet/indirector/file_metadata/file'

describe Puppet::Indirector::FileMetadata::File do
  it "should be registered with the file_metadata indirection" do
    expect(Puppet::Indirector::Terminus.terminus_class(:file_metadata, :file)).to equal(Puppet::Indirector::FileMetadata::File)
  end

  it "should be a subclass of the DirectFileServer terminus" do
    expect(Puppet::Indirector::FileMetadata::File.superclass).to equal(Puppet::Indirector::DirectFileServer)
  end

  describe "when creating the instance for a single found file" do
    before do
      @metadata = Puppet::Indirector::FileMetadata::File.new
      @path = File.expand_path('/my/local')
      @uri = Puppet::Util.path_to_uri(@path).to_s
      @data = double('metadata')
      allow(@data).to receive(:collect)
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)

      @request = Puppet::Indirector::Request.new(:file_metadata, :find, @uri, nil)
    end

    it "should collect its attributes when a file is found" do
      expect(@data).to receive(:collect)

      expect(Puppet::FileServing::Metadata).to receive(:new).and_return(@data)
      expect(@metadata.find(@request)).to eq(@data)
    end
  end

  describe "when searching for multiple files" do
    before do
      @metadata = Puppet::Indirector::FileMetadata::File.new
      @path = File.expand_path('/my/local')
      @uri = Puppet::Util.path_to_uri(@path).to_s

      @request = Puppet::Indirector::Request.new(:file_metadata, :find, @uri, nil)
    end

    it "should collect the attributes of the instances returned" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
      expect(Puppet::FileServing::Fileset).to receive(:new).with(@path, @request).and_return(double("fileset"))
      expect(Puppet::FileServing::Fileset).to receive(:merge).and_return([["one", @path], ["two", @path]])

      one = double("one", :collect => nil)
      expect(Puppet::FileServing::Metadata).to receive(:new).with(@path, {:relative_path => "one"}).and_return(one)

      two = double("two", :collect => nil)
      expect(Puppet::FileServing::Metadata).to receive(:new).with(@path, {:relative_path => "two"}).and_return(two)

      expect(@metadata.search(@request)).to eq([one, two])
    end
  end
end
