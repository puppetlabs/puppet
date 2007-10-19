#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/metadata'

describe Puppet::FileServing::Metadata do
    it "should indirect file_metadata" do
        Puppet::FileServing::Metadata.indirection.name.should == :file_metadata
    end

    it "should should include the TerminusSelector module in its indirection" do
        Puppet::FileServing::Metadata.indirection.metaclass.included_modules.should include(Puppet::FileServing::TerminusSelector)
    end
end

describe Puppet::FileServing::Metadata, " when initializing" do
    it "should allow initialization without a path" do
        proc { Puppet::FileServing::Metadata.new() }.should_not raise_error
    end

    it "should allow initialization with a path" do
        proc { Puppet::FileServing::Metadata.new("unqualified") }.should raise_error(ArgumentError)
    end

    it "should the path to be fully qualified if it is provied" do
        proc { Puppet::FileServing::Metadata.new("unqualified") }.should raise_error(ArgumentError)
    end

    it "should require the path to exist if it is provided" do
        FileTest.expects(:exists?).with("/no/such/path").returns(false)
        proc { Puppet::FileServing::Metadata.new("/no/such/path") }.should raise_error(ArgumentError)
    end
end

describe Puppet::FileServing::Metadata do
    before do
        @path = "/my/file"
        @stat = mock 'stat', :uid => 10, :gid => 20, :mode => 0755
        File.stubs(:stat).returns(@stat)
        @filehandle = mock 'filehandle'
        @filehandle.expects(:each_line).yields("some content\n")
        File.stubs(:open).with(@path, 'r').yields(@filehandle)
        @checksum = Digest::MD5.hexdigest("some content\n")
        FileTest.expects(:exists?).with(@path).returns(true)
        @metadata = Puppet::FileServing::Metadata.new(@path)
        @metadata.get_attributes
    end

    it "should accept a file path" do
        @metadata.path.should == @path
    end

    # LAK:FIXME This should actually change at some point
    it "should set the owner by id" do
        @metadata.owner.should be_instance_of(Fixnum)
    end

    # LAK:FIXME This should actually change at some point
    it "should set the group by id" do
        @metadata.group.should be_instance_of(Fixnum)
    end

    it "should set the owner to the file's current owner" do
        @metadata.owner.should == 10
    end

    it "should set the group to the file's current group" do
        @metadata.group.should == 20
    end

    it "should set the mode to a string version of the mode in octal" do
        @metadata.mode.should == "755"
    end

    it "should set the mode to the file's current mode" do
        @metadata.mode.should == "755"
    end

    it "should set the checksum to the file's current checksum" do
        @metadata.checksum.should == "{md5}" + @checksum
    end

    it "should default to a checksum of type MD5" do
        @metadata.checksum.should == "{md5}" + @checksum
    end
end

describe Puppet::FileServing::Metadata, " when converting from yaml" do
    # LAK:FIXME This isn't in the right place, but we need some kind of
    # control somewhere that requires that all REST connections only pull
    # from the file-server, thus guaranteeing they go through our authorization
    # hook.
    it "should set the URI scheme to 'puppetmounts'" do
        pending "We need to figure out where this should be"
    end
end
