#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/file'

module FileTerminusTesting
    def setup
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @file_class = Class.new(Puppet::Indirector::File) do
            def self.to_s
                "Testing"
            end
        end

        @searcher = @file_class.new

        @path = "/my/file"
        @dir = "/my"
    end
end

describe Puppet::Indirector::File, " when finding files" do
    include FileTerminusTesting

    it "should provide a method to return file contents at a specified path" do
    end

    it "should return file contents as an instance of the model" do
        content = "my content"

        file = mock 'file'
        @model.expects(:new).with(@path).returns(file)
        file.expects(:content=).with(content)

        File.expects(:exist?).with(@path).returns(true)
        File.expects(:read).with(@path).returns(content)
        @searcher.find(@path)
    end

    it "should set the file contents as the 'content' attribute of the returned instance" do
        content = "my content"

        file = mock 'file'
        @model.expects(:new).with(@path).returns(file)
        file.expects(:content=).with(content)

        File.expects(:exist?).with(@path).returns(true)
        File.expects(:read).with(@path).returns(content)
        @searcher.find(@path).should equal(file)
    end

    it "should return nil if no file is found" do
        File.expects(:exist?).with(@path).returns(false)
        @searcher.find(@path).should be_nil
    end

    it "should fail intelligently if a found file cannot be read" do
        content = "my content"
        File.expects(:exist?).with(@path).returns(true)
        File.expects(:read).with(@path).raises(RuntimeError)
        proc { @searcher.find(@path) }.should raise_error(Puppet::Error)
    end
end

describe Puppet::Indirector::File, " when saving files" do
    include FileTerminusTesting

    it "should provide a method to save file contents at a specified path" do
        filehandle = mock 'file'
        content = "my content"
        File.expects(:directory?).with(@dir).returns(true)
        File.expects(:open).with(@path, "w").yields(filehandle)
        filehandle.expects(:print).with(content)

        file = stub 'file', :content => content, :path => @path, :name => @path

        @searcher.save(file)
    end

    it "should fail intelligently if the file's parent directory does not exist" do
        File.expects(:directory?).with(@dir).returns(false)

        file = stub 'file', :path => @path, :name => @path

        proc { @searcher.save(file) }.should raise_error(Puppet::Error)
    end

    it "should fail intelligently if a file cannot be written" do
        filehandle = mock 'file'
        content = "my content"
        File.expects(:directory?).with(@dir).returns(true)
        File.expects(:open).with(@path, "w").yields(filehandle)
        filehandle.expects(:print).with(content).raises(ArgumentError)

        file = stub 'file', :content => content, :path => @path, :name => @path

        proc { @searcher.save(file) }.should raise_error(Puppet::Error)
    end
end

describe Puppet::Indirector::File, " when removing files" do
    include FileTerminusTesting

    it "should provide a method to remove files at a specified path" do
        file = stub 'file', :path => @path, :name => @path
        File.expects(:exist?).with(@path).returns(true)
        File.expects(:unlink).with(@path)

        @searcher.destroy(file)
    end

    it "should throw an exception if the file is not found" do
        file = stub 'file', :path => @path, :name => @path
        File.expects(:exist?).with(@path).returns(false)

        proc { @searcher.destroy(file) }.should raise_error(Puppet::Error)
    end

    it "should fail intelligently if the file cannot be removed" do
        file = stub 'file', :path => @path, :name => @path
        File.expects(:exist?).with(@path).returns(true)
        File.expects(:unlink).with(@path).raises(ArgumentError)

        proc { @searcher.destroy(file) }.should raise_error(Puppet::Error)
    end
end
