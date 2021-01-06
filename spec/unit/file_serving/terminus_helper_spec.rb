require 'spec_helper'

require 'puppet/file_serving/terminus_helper'

class Puppet::FileServing::TestHelper
  include Puppet::FileServing::TerminusHelper

  attr_reader :model

  def initialize(model)
    @model = model
  end
end

describe Puppet::FileServing::TerminusHelper do
  before do
    @model = double('model')
    @helper = Puppet::FileServing::TestHelper.new(@model)

    @request = double('request', :key => "url", :options => {})

    @fileset = double('fileset', :files => [], :path => "/my/file")
    allow(Puppet::FileServing::Fileset).to receive(:new).with("/my/file", {}).and_return(@fileset)
  end

  it "should find a file with absolute path" do
    file = double('file', :collect => nil)
    expect(file).to receive(:collect).with(no_args)
    expect(@model).to receive(:new).with("/my/file", {:relative_path => nil}).and_return(file)
    @helper.path2instance(@request, "/my/file")
  end

  it "should pass through links, checksum_type, and source_permissions" do
    file = double('file', :checksum_type= => nil, :links= => nil, :collect => nil)
    [[:checksum_type, :sha256], [:links, true], [:source_permissions, :use]].each {|k, v|
      expect(file).to receive(k.to_s+'=').with(v)
      @request.options[k] = v
    }
    expect(file).to receive(:collect)
    expect(@model).to receive(:new).with("/my/file", {:relative_path => :file}).and_return(file)
    @helper.path2instance(@request, "/my/file", {:relative_path => :file})
  end

  it "should use a fileset to find paths" do
    @fileset = double('fileset', :files => [], :path => "/my/files")
    expect(Puppet::FileServing::Fileset).to receive(:new).with("/my/file", anything).and_return(@fileset)
    @helper.path2instances(@request, "/my/file")
  end

  it "should support finding across multiple paths by merging the filesets" do
    first = double('fileset', :files => [], :path => "/first/file")
    expect(Puppet::FileServing::Fileset).to receive(:new).with("/first/file", anything).and_return(first)
    second = double('fileset', :files => [], :path => "/second/file")
    expect(Puppet::FileServing::Fileset).to receive(:new).with("/second/file", anything).and_return(second)

    expect(Puppet::FileServing::Fileset).to receive(:merge).with(first, second).and_return({})

    @helper.path2instances(@request, "/first/file", "/second/file")
  end

  it "should pass the indirection request to the Fileset at initialization" do
    expect(Puppet::FileServing::Fileset).to receive(:new).with(anything, @request).and_return(@fileset)
    @helper.path2instances(@request, "/my/file")
  end

  describe "when creating instances" do
    before do
      allow(@request).to receive(:key).and_return("puppet://host/mount/dir")

      @one = double('one', :links= => nil, :collect => nil)
      @two = double('two', :links= => nil, :collect => nil)

      @fileset = double('fileset', :files => %w{one two}, :path => "/my/file")
      allow(Puppet::FileServing::Fileset).to receive(:new).and_return(@fileset)
    end

    it "should set each returned instance's path to the original path" do
      expect(@model).to receive(:new).with("/my/file", anything).and_return(@one, @two)
      @helper.path2instances(@request, "/my/file")
    end

    it "should set each returned instance's relative path to the file-specific path" do
      expect(@model).to receive(:new).with(anything, hash_including(relative_path: "one")).and_return(@one)
      expect(@model).to receive(:new).with(anything, hash_including(relative_path: "two")).and_return(@two)
      @helper.path2instances(@request, "/my/file")
    end

    it "should set the links value on each instance if one is provided" do
      expect(@one).to receive(:links=).with(:manage)
      expect(@two).to receive(:links=).with(:manage)
      expect(@model).to receive(:new).and_return(@one, @two)

      @request.options[:links] = :manage
      @helper.path2instances(@request, "/my/file")
    end

    it "should set the request checksum_type if one is provided" do
      expect(@one).to receive(:checksum_type=).with(:test)
      expect(@two).to receive(:checksum_type=).with(:test)
      expect(@model).to receive(:new).and_return(@one, @two)

      @request.options[:checksum_type] = :test
      @helper.path2instances(@request, "/my/file")
    end

    it "should collect the instance's attributes" do
      expect(@one).to receive(:collect)
      expect(@two).to receive(:collect)
      expect(@model).to receive(:new).and_return(@one, @two)

      @helper.path2instances(@request, "/my/file")
    end
  end
end
