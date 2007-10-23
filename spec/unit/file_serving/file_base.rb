#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/file_base'

describe Puppet::FileServing::FileBase, " when initializing" do
    it "should accept a file path" do
        Puppet::FileServing::FileBase.new("not/qualified").path.should == "not/qualified"
    end

    it "should not allow a fully qualified file path" do
        proc { Puppet::FileServing::FileBase.new("/fully/qualified") }.should raise_error(ArgumentError)
    end

    it "should allow specification of whether links should be managed" do
        Puppet::FileServing::FileBase.new("not/qualified", :links => :manage).links.should == :manage
    end

    it "should fail if :links is set to anything other than :manage or :follow" do
        proc { Puppet::FileServing::FileBase.new("not/qualified", :links => :else) }.should raise_error(ArgumentError)
    end

    it "should default to :manage for :links" do
        Puppet::FileServing::FileBase.new("not/qualified").links.should == :manage
    end
end

describe Puppet::FileServing::FileBase do
    it "should provide a method for setting the base path" do
        @file = Puppet::FileServing::FileBase.new("not/qualified")
        @file.base_path = "/something"
        @file.base_path.should == "/something"
    end
end

describe Puppet::FileServing::FileBase, " when determining the full file path" do
    it "should return the provided path joined with the qualified path if a path is provided" do
        @file = Puppet::FileServing::FileBase.new("not/qualified")
        @file.full_path("/this/file").should == "/this/file/not/qualified"
    end

    it "should return the set base path joined with the qualified path if a base path is set" do
        @file = Puppet::FileServing::FileBase.new("not/qualified")
        @file.base_path = "/this/file"
        @file.full_path.should == "/this/file/not/qualified"
    end

    it "should should fail if a base path is neither provided nor set" do
        @file = Puppet::FileServing::FileBase.new("not/qualified")
        proc { @file.full_path }.should raise_error(ArgumentError)
    end
end

describe Puppet::FileServing::FileBase, " when stat'ing files" do
    before do
        @file = Puppet::FileServing::FileBase.new("not/qualified")
    end

    it "should join the provided path with the qualified path is a path is provided" do
        File.expects(:lstat).with("/this/file/not/qualified").returns stub("stat", :ftype => "file")
        @file.stat("/this/file")
    end

    it "should use the set base path if no base is provided" do
        @file.base_path = "/this/file"
        File.expects(:lstat).with("/this/file/not/qualified").returns stub("stat", :ftype => "file")
        @file.stat
    end

    it "should fail if a base path is neither set nor provided" do
        proc { @file.stat }.should raise_error(ArgumentError)
    end

    it "should use :lstat if :links is set to :manage" do
        File.expects(:lstat).with("/this/file/not/qualified").returns stub("stat", :ftype => "file")
        @file.stat("/this/file")
    end

    it "should use :stat if :links is set to :follow" do
        File.expects(:stat).with("/this/file/not/qualified").returns stub("stat", :ftype => "file")
        @file.links = :follow
        @file.stat("/this/file")
    end
end
