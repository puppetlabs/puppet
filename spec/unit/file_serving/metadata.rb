#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/metadata'

describe Puppet::FileServing::Metadata do
    it "should should be a subclass of Base" do
        Puppet::FileServing::Metadata.superclass.should equal(Puppet::FileServing::Base)
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

        # Use a link because it's easier to test -- no checksumming
        @stat = stub "stat", :uid => 10, :gid => 20, :mode => 0755, :ftype => "link"
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
        # Use a real file mode, so we can validate the masking is done.
        @stat = stub 'stat', :uid => 10, :gid => 20, :mode => 33261, :ftype => "file"
        File.stubs(:lstat).returns(@stat)
        @checksum = Digest::MD5.hexdigest("some content\n")
        @metadata = Puppet::FileServing::Metadata.new("file", :path => "/my/file")
        @metadata.stubs(:md5_file).returns(@checksum)
        @metadata.collect_attributes
    end

    it "should be able to produce xmlrpc-style attribute information" do
        @metadata.should respond_to(:attributes_with_tabs)
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

    it "should set the mode to the file's masked mode" do
        @metadata.mode.should == 0755
    end

    it "should set the checksum to the file's current checksum" do
        @metadata.checksum.should == "{md5}" + @checksum
    end

    describe "when managing files" do
        it "should default to a checksum of type MD5" do
            @metadata.checksum.should == "{md5}" + @checksum
        end

        it "should produce tab-separated mode, type, owner, group, and checksum for xmlrpc" do
            @metadata.attributes_with_tabs.should == "#{0755.to_s}\tfile\t10\t20\t{md5}#{@checksum}"
        end
    end

    describe "when managing directories" do
        before do
            @stat.stubs(:ftype).returns("directory")
            @time = Time.now
            @metadata.expects(:ctime_file).returns(@time)
            @metadata.collect_attributes
        end

        it "should only use checksums of type 'ctime' for directories" do
            @metadata.checksum.should == "{ctime}" + @time.to_s
        end

        it "should produce tab-separated mode, type, owner, group, and checksum for xmlrpc" do
            @metadata.attributes_with_tabs.should == "#{0755.to_s}\tdirectory\t10\t20\t{ctime}#{@time.to_s}"
        end
    end

    describe "when managing links" do
        before do
            @stat.stubs(:ftype).returns("link")
            File.expects(:readlink).with("/my/file").returns("/path/to/link")
            @metadata.collect_attributes
        end

        it "should read links instead of returning their checksums" do
            @metadata.destination.should == "/path/to/link"
        end

        it "should produce tab-separated mode, type, owner, group, and destination for xmlrpc" do
            @metadata.attributes_with_tabs.should == "#{0755.to_s}\tlink\t10\t20\t/path/to/link"
        end
    end
end

describe Puppet::FileServing::Metadata, " when pointing to a link" do
    it "should store the destination of the link in :destination if links are :manage" do
        file = Puppet::FileServing::Metadata.new("mykey", :links => :manage, :path => "/base/path/my/file")

        File.expects(:lstat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "link", :mode => 0755)
        File.expects(:readlink).with("/base/path/my/file").returns "/some/other/path"

        file.collect_attributes
        file.destination.should == "/some/other/path"
    end

    it "should not collect the checksum" do
        file = Puppet::FileServing::Metadata.new("my/file", :links => :manage, :path => "/base/path/my/file")

        File.expects(:lstat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "link", :mode => 0755)
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
