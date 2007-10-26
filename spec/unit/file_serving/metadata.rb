#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/metadata'

describe Puppet::FileServing::Metadata do
    it "should should be a subclass of FileBase" do
        Puppet::FileServing::Metadata.superclass.should equal(Puppet::FileServing::FileBase)
    end

    it "should indirect file_metadata" do
        Puppet::FileServing::Metadata.indirection.name.should == :file_metadata
    end

    it "should should include the IndirectionHooks module in its indirection" do
        Puppet::FileServing::Metadata.indirection.metaclass.included_modules.should include(Puppet::FileServing::IndirectionHooks)
    end
end

describe Puppet::FileServing::Metadata, " when finding the file to use for setting attributes" do
    before do
        @metadata = Puppet::FileServing::Metadata.new("my/path")

        @full = "/base/path/my/path"

        @metadata.path = @full

        # Use a symlink because it's easier to test -- no checksumming
        @stat = stub "stat", :uid => 10, :gid => 20, :mode => 0755, :ftype => "symlink"
    end

    it "should accept a base path path to which the file should be relative" do
        File.expects(:lstat).with(@full).returns @stat
        File.expects(:readlink).with(@full).returns "/what/ever"
        @metadata.collect_attributes
    end

    it "should use the set base path if one is not provided" do
        File.expects(:lstat).with(@full).returns @stat
        File.expects(:readlink).with(@full).returns "/what/ever"
        @metadata.collect_attributes()
    end

    it "should fail if a base path is neither set nor provided" do
        proc { @metadata.collect_attributes() }.should raise_error(Errno::ENOENT)
    end

    it "should raise an exception if the file does not exist" do
        File.expects(:lstat).with(@full).raises(Errno::ENOENT)
        proc { @metadata.collect_attributes()}.should raise_error(Errno::ENOENT)
    end
end

describe Puppet::FileServing::Metadata, " when collecting attributes" do
    before do
        @path = "/my/file"
        @stat = stub 'stat', :uid => 10, :gid => 20, :mode => 0755, :ftype => "file"
        File.stubs(:lstat).returns(@stat)
        @filehandle = mock 'filehandle'
        @filehandle.expects(:each_line).yields("some content\n")
        File.stubs(:open).with(@path, 'r').yields(@filehandle)
        @checksum = Digest::MD5.hexdigest("some content\n")
        @metadata = Puppet::FileServing::Metadata.new("file", :path => "/my/file")
        @metadata.collect_attributes
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

describe Puppet::FileServing::Metadata, " when pointing to a symlink" do
    it "should store the destination of the symlink in :destination if links are :manage" do
        file = Puppet::FileServing::Metadata.new("mykey", :links => :manage, :path => "/base/path/my/file")

        File.expects(:lstat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "symlink", :mode => 0755)
        File.expects(:readlink).with("/base/path/my/file").returns "/some/other/path"

        file.collect_attributes
        file.destination.should == "/some/other/path"
    end

    it "should not collect the checksum" do
        file = Puppet::FileServing::Metadata.new("my/file", :links => :manage, :path => "/base/path/my/file")

        File.expects(:lstat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "symlink", :mode => 0755)
        File.expects(:readlink).with("/base/path/my/file").returns "/some/other/path"

        file.collect_attributes
        file.checksum.should be_nil
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
