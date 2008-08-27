#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/terminus_helper'

describe Puppet::FileServing::TerminusHelper do
    before do
        @helper = Object.new
        @helper.extend(Puppet::FileServing::TerminusHelper)

        @model = mock 'model'
        @helper.stubs(:model).returns(@model)

        @request = stub 'request', :key => "url", :options => {}
    end

    it "should use a fileset to find paths" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", {}).returns(fileset)
        @helper.path2instances(@request, "/my/file")
    end

    it "should pass :recurse, :ignore, and :links settings on to the fileset if present" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", :links => :a, :ignore => :b, :recurse => :c).returns(fileset)
        @request.stubs(:options).returns(:links => :a, :ignore => :b, :recurse => :c)
        @helper.path2instances(@request, "/my/file")
    end

    it "should pass :recurse, :ignore, and :links settings on to the fileset if present with the keys stored as strings" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", :links => :a, :ignore => :b, :recurse => :c).returns(fileset)
        @request.stubs(:options).returns("links" => :a, "ignore" => :b, "recurse" => :c)
        @helper.path2instances(@request, "/my/file")
    end

    it "should convert the string 'true' to the boolean true when setting options" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", :recurse => true).returns(fileset)
        @request.stubs(:options).returns(:recurse => "true")
        @helper.path2instances(@request, "/my/file")
    end

    it "should convert the string 'false' to the boolean false when setting options" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", :recurse => false).returns(fileset)
        @request.stubs(:options).returns(:recurse => "false")
        @helper.path2instances(@request, "/my/file")
    end

    describe "when creating instances" do
        before do
            @request.stubs(:key).returns "puppet://host/mount/dir"

            @one = stub 'one', :links= => nil, :collect => nil
            @two = stub 'two', :links= => nil, :collect => nil

            @fileset = mock 'fileset', :files => %w{one two}
            Puppet::FileServing::Fileset.expects(:new).returns(@fileset)
        end

        it "should create an instance of the model for each path returned by the fileset" do
            @model.expects(:new).returns(@one)
            @model.expects(:new).returns(@two)
            @helper.path2instances(@request, "/my/file").length.should == 2
        end

        it "should set each returned instance's path to the original path" do
            @model.expects(:new).with { |key, options| key == "/my/file" }.returns(@one)
            @model.expects(:new).with { |key, options| key == "/my/file" }.returns(@two)
            @helper.path2instances(@request, "/my/file")
        end

        it "should set each returned instance's relative path to the file-specific path" do
            @model.expects(:new).with { |key, options| options[:relative_path] == "one" }.returns(@one)
            @model.expects(:new).with { |key, options| options[:relative_path] == "two" }.returns(@two)
            @helper.path2instances(@request, "/my/file")
        end

        it "should set the links value on each instance if one is provided" do
            @one.expects(:links=).with :manage
            @two.expects(:links=).with :manage
            @model.expects(:new).returns(@one)
            @model.expects(:new).returns(@two)

            @request.options[:links] = :manage
            @helper.path2instances(@request, "/my/file")
        end

        it "should collect the instance's attributes" do
            @one.expects(:collect)
            @two.expects(:collect)
            @model.expects(:new).returns(@one)
            @model.expects(:new).returns(@two)

            @helper.path2instances(@request, "/my/file")
        end
    end
end
