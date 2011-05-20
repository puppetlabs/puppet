#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/indirector/file'


describe Puppet::Indirector::File do
  before :all do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @file_class = class Testing::MyFile < Puppet::Indirector::File
      self
    end

    @searcher = @file_class.new

    @path = "/my/file"
    @dir = "/my"

    @request = stub 'request', :key => @path
  end

  describe "when finding files" do
    it "should provide a method to return file contents at a specified path" do
      @searcher.should respond_to(:find)
    end

    it "should use the server data directory plus the indirection name if the run_mode is master" do
      Puppet.run_mode.expects(:master?).returns true
      Puppet.settings.expects(:value).with(:server_datadir).returns "/my/dir"

      @searcher.data_directory.should == File.join("/my/dir", "mystuff")
    end

    it "should use the client data directory plus the indirection name if the run_mode is not master" do
      Puppet.run_mode.expects(:master?).returns false
      Puppet.settings.expects(:value).with(:client_datadir).returns "/my/dir"

      @searcher.data_directory.should == File.join("/my/dir", "mystuff")
    end

    it "should use the newest file in the data directory matching the indirection key without extension" do
      @searcher.expects(:data_directory).returns "/data/dir"
      @request.stubs(:key).returns "foo"
      Dir.expects(:glob).with("/data/dir/foo.*").returns %w{/data1.stuff /data2.stuff}

      stat1 = stub 'data1', :mtime => (Time.now - 5)
      stat2 = stub 'data2', :mtime => Time.now
      File.expects(:stat).with("/data1.stuff").returns stat1
      File.expects(:stat).with("/data2.stuff").returns stat2

      @searcher.latest_path(@request).should == "/data2.stuff"
    end

    it "should return nil when no files are found" do
      @searcher.stubs(:latest_path).returns nil

      @searcher.find(@request).should be_nil
    end

    it "should determine the file format from the file extension" do
      @searcher.file_format("/data2.pson").should == "pson"
    end

    it "should fail if the model does not support the file format" do
      @searcher.stubs(:latest_path).returns "/my/file.pson"

      @model.expects(:support_format?).with("pson").returns false

      lambda { @searcher.find(@request) }.should raise_error(ArgumentError)
    end
  end

  describe "when saving files" do
    before do
      @content = "my content"
      @file = stub 'file', :content => @content, :path => @path, :name => @path, :render => "mydata"
      @request.stubs(:instance).returns @file
    end

    it "should provide a method to save file contents at a specified path" do
      @searcher.should respond_to(:save)
    end

    it "should choose the file extension based on the default format of the model" do
      @model.expects(:default_format).returns "pson"

      @searcher.serialization_format.should == "pson"
    end

    it "should place the file in the data directory, named after the indirection, key, and format" do
      @searcher.stubs(:data_directory).returns "/my/dir"
      @searcher.stubs(:serialization_format).returns "pson"

      @request.stubs(:key).returns "foo"
      @searcher.file_path(@request).should == File.join("/my/dir", "foo.pson")
    end

    it "should fail intelligently if the file's parent directory does not exist" do
      @searcher.stubs(:file_path).returns "/my/dir/file.pson"
      @searcher.stubs(:serialization_format).returns "pson"

      @request.stubs(:key).returns "foo"
      File.expects(:directory?).with(File.join("/my/dir")).returns(false)

      proc { @searcher.save(@request) }.should raise_error(Puppet::Error)
    end

    it "should render the instance using the file format and print it to the file path" do
      @searcher.stubs(:file_path).returns "/my/file.pson"
      @searcher.stubs(:serialization_format).returns "pson"

      File.stubs(:directory?).returns true

      @request.instance.expects(:render).with("pson").returns "data"

      fh = mock 'filehandle'
      File.expects(:open).with("/my/file.pson", "w").yields fh
      fh.expects(:print).with("data")

      @searcher.save(@request)
    end

    it "should fail intelligently if a file cannot be written" do
      filehandle = mock 'file'
      File.stubs(:directory?).returns(true)
      File.stubs(:open).yields(filehandle)
      filehandle.expects(:print).raises(ArgumentError)

      @searcher.stubs(:file_path).returns "/my/file.pson"
      @model.stubs(:default_format).returns "pson"

      @instance.stubs(:render).returns "stuff"

      proc { @searcher.save(@request) }.should raise_error(Puppet::Error)
    end
  end

  describe "when removing files" do
    it "should provide a method to remove files" do
      @searcher.should respond_to(:destroy)
    end

    it "should remove files in all formats found in the data directory that match the request key" do
      @searcher.stubs(:data_directory).returns "/my/dir"
      @request.stubs(:key).returns "me"

      Dir.expects(:glob).with(File.join("/my/dir", "me.*")).returns %w{/one /two}

      File.expects(:unlink).with("/one")
      File.expects(:unlink).with("/two")

      @searcher.destroy(@request)
    end

    it "should throw an exception if no file is found" do
      @searcher.stubs(:data_directory).returns "/my/dir"
      @request.stubs(:key).returns "me"

      Dir.expects(:glob).with(File.join("/my/dir", "me.*")).returns []

      proc { @searcher.destroy(@request) }.should raise_error(Puppet::Error)
    end

    it "should fail intelligently if a file cannot be removed" do
      @searcher.stubs(:data_directory).returns "/my/dir"
      @request.stubs(:key).returns "me"

      Dir.expects(:glob).with(File.join("/my/dir", "me.*")).returns %w{/one}

      File.expects(:unlink).with("/one").raises ArgumentError

      proc { @searcher.destroy(@request) }.should raise_error(Puppet::Error)
    end
  end
end
