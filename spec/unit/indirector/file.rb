#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/file'


describe Puppet::Indirector::File do
    before :each do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @file_class = Class.new(Puppet::Indirector::File) do
            def self.to_s
                "Testing::Mytype"
            end
        end

        @searcher = @file_class.new

        @path = "/my/file"
        @dir = "/my"

        @request = stub 'request', :key => @path
    end
  
    describe Puppet::Indirector::File, " when finding files" do

        it "should provide a method to return file contents at a specified path" do
            @searcher.should respond_to(:find)
        end

        it "should return file contents as an instance of the model" do
            content = "my content"

            file = mock 'file'
            @model.expects(:new).with(content).returns(file)

            File.expects(:exist?).with(@path).returns(true)
            File.expects(:read).with(@path).returns(content)
            @searcher.find(@request)
        end

        it "should create the model instance with the content as the only argument to initialization" do
            content = "my content"

            file = mock 'file'
            @model.expects(:new).with(content).returns(file)

            File.expects(:exist?).with(@path).returns(true)
            File.expects(:read).with(@path).returns(content)
            @searcher.find(@request).should equal(file)
        end

        it "should return nil if no file is found" do
            File.expects(:exist?).with(@path).returns(false)
            @searcher.find(@request).should be_nil
        end

        it "should fail intelligently if a found file cannot be read" do
            File.expects(:exist?).with(@path).returns(true)
            File.expects(:read).with(@path).raises(RuntimeError)
            proc { @searcher.find(@request) }.should raise_error(Puppet::Error)
        end

        it "should use the path() method to calculate the path if it exists" do
            @searcher.meta_def(:path) do |name|
                name.upcase
            end

            File.expects(:exist?).with(@path.upcase).returns(false)
            @searcher.find(@request)
        end
    end

    describe Puppet::Indirector::File, " when saving files" do
        before do
            @content = "my content"
            @file = stub 'file', :content => @content, :path => @path, :name => @path
            @request.stubs(:instance).returns @file
        end

        it "should provide a method to save file contents at a specified path" do
            filehandle = mock 'file'
            File.expects(:directory?).with(@dir).returns(true)
            File.expects(:open).with(@path, "w").yields(filehandle)
            filehandle.expects(:print).with(@content)

            @searcher.save(@request)
        end

        it "should fail intelligently if the file's parent directory does not exist" do
            File.expects(:directory?).with(@dir).returns(false)

            proc { @searcher.save(@request) }.should raise_error(Puppet::Error)
        end

        it "should fail intelligently if a file cannot be written" do
            filehandle = mock 'file'
            File.expects(:directory?).with(@dir).returns(true)
            File.expects(:open).with(@path, "w").yields(filehandle)
            filehandle.expects(:print).with(@content).raises(ArgumentError)

            proc { @searcher.save(@request) }.should raise_error(Puppet::Error)
        end

        it "should use the path() method to calculate the path if it exists" do
            @searcher.meta_def(:path) do |name|
                name.upcase
            end

            # Reset the key to something without a parent dir, so no checks are necessary
            @request.stubs(:key).returns "/my"

            File.expects(:open).with("/MY", "w")
            @searcher.save(@request)
        end
    end

    describe Puppet::Indirector::File, " when removing files" do

        it "should provide a method to remove files at a specified path" do
            File.expects(:exist?).with(@path).returns(true)
            File.expects(:unlink).with(@path)

            @searcher.destroy(@request)
        end

        it "should throw an exception if the file is not found" do
            File.expects(:exist?).with(@path).returns(false)

            proc { @searcher.destroy(@request) }.should raise_error(Puppet::Error)
        end

        it "should fail intelligently if the file cannot be removed" do
            File.expects(:exist?).with(@path).returns(true)
            File.expects(:unlink).with(@path).raises(ArgumentError)

            proc { @searcher.destroy(@request) }.should raise_error(Puppet::Error)
        end

        it "should use the path() method to calculate the path if it exists" do
            @searcher.meta_def(:path) do |thing|
                thing.to_s.upcase
            end

            File.expects(:exist?).with("/MY/FILE").returns(true)
            File.expects(:unlink).with("/MY/FILE")

            @searcher.destroy(@request)
        end
    end
end
