#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_serving/metadata'

describe Puppet::FileServing::Metadata do
  it "should should be a subclass of Base" do
    Puppet::FileServing::Metadata.superclass.should equal(Puppet::FileServing::Base)
  end

  it "should indirect file_metadata" do
    Puppet::FileServing::Metadata.indirection.name.should == :file_metadata
  end

  it "should should include the IndirectionHooks module in its indirection" do
    Puppet::FileServing::Metadata.indirection.singleton_class.included_modules.should include(Puppet::FileServing::IndirectionHooks)
  end

  it "should have a method that triggers attribute collection" do
    Puppet::FileServing::Metadata.new("/foo/bar").should respond_to(:collect)
  end

  it "should support pson serialization" do
    Puppet::FileServing::Metadata.new("/foo/bar").should respond_to(:to_pson)
  end

  it "should support to_pson_data_hash" do
    Puppet::FileServing::Metadata.new("/foo/bar").should respond_to(:to_pson_data_hash)
  end

  it "should support pson deserialization" do
    Puppet::FileServing::Metadata.should respond_to(:from_pson)
  end

  describe "when serializing" do
    before do
      @metadata = Puppet::FileServing::Metadata.new("/foo/bar")
    end
    it "should perform pson serialization by calling to_pson on it's pson_data_hash" do
      pdh = mock "data hash"
      pdh_as_pson = mock "data as pson"
      @metadata.expects(:to_pson_data_hash).returns pdh
      pdh.expects(:to_pson).returns pdh_as_pson
      @metadata.to_pson.should == pdh_as_pson
    end

    it "should serialize as FileMetadata" do
      @metadata.to_pson_data_hash['document_type'].should == "FileMetadata"
    end

    it "the data should include the path, relative_path, links, owner, group, mode, checksum, type, and destination" do
      @metadata.to_pson_data_hash['data'].keys.sort.should == %w{ path relative_path links owner group mode checksum type destination }.sort
    end

    it "should pass the path in the hash verbatum" do
      @metadata.to_pson_data_hash['data']['path'] == @metadata.path
    end

    it "should pass the relative_path in the hash verbatum" do
      @metadata.to_pson_data_hash['data']['relative_path'] == @metadata.relative_path
    end

    it "should pass the links in the hash verbatum" do
      @metadata.to_pson_data_hash['data']['links'] == @metadata.links
    end

    it "should pass the path owner in the hash verbatum" do
      @metadata.to_pson_data_hash['data']['owner'] == @metadata.owner
    end

    it "should pass the group in the hash verbatum" do
      @metadata.to_pson_data_hash['data']['group'] == @metadata.group
    end

    it "should pass the mode in the hash verbatum" do
      @metadata.to_pson_data_hash['data']['mode'] == @metadata.mode
    end

    it "should pass the ftype in the hash verbatum as the 'type'" do
      @metadata.to_pson_data_hash['data']['type'] == @metadata.ftype
    end

    it "should pass the destination verbatum" do
      @metadata.to_pson_data_hash['data']['destination'] == @metadata.destination
    end

    it "should pass the checksum in the hash as a nested hash" do
      @metadata.to_pson_data_hash['data']['checksum'].should be_is_a(Hash)
    end

    it "should pass the checksum_type in the hash verbatum as the checksum's type" do
      @metadata.to_pson_data_hash['data']['checksum']['type'] == @metadata.checksum_type
    end

    it "should pass the checksum in the hash verbatum as the checksum's value" do
      @metadata.to_pson_data_hash['data']['checksum']['value'] == @metadata.checksum
    end

  end
end

describe Puppet::FileServing::Metadata, " when finding the file to use for setting attributes" do
  before do
    @path = "/my/path"
    @metadata = Puppet::FileServing::Metadata.new(@path)

    # Use a link because it's easier to test -- no checksumming
    @stat = stub "stat", :uid => 10, :gid => 20, :mode => 0755, :ftype => "link"

    # Not quite.  We don't want to checksum links, but we must because they might be being followed.
    @checksum = Digest::MD5.hexdigest("some content\n") # Remove these when :managed links are no longer checksumed.
    @metadata.stubs(:md5_file).returns(@checksum)           #
  end

  it "should accept a base path path to which the file should be relative" do
    File.expects(:lstat).with(@path).returns @stat
    File.expects(:readlink).with(@path).returns "/what/ever"
    @metadata.collect
  end

  it "should use the set base path if one is not provided" do
    File.expects(:lstat).with(@path).returns @stat
    File.expects(:readlink).with(@path).returns "/what/ever"
    @metadata.collect
  end

  it "should raise an exception if the file does not exist" do
    File.expects(:lstat).with(@path).raises(Errno::ENOENT)
    proc { @metadata.collect}.should raise_error(Errno::ENOENT)
  end
end

describe Puppet::FileServing::Metadata, " when collecting attributes" do
  before do
    @path = "/my/file"
    # Use a real file mode, so we can validate the masking is done.
    @stat = stub 'stat', :uid => 10, :gid => 20, :mode => 33261, :ftype => "file"
    File.stubs(:lstat).returns(@stat)
    @checksum = Digest::MD5.hexdigest("some content\n")
    @metadata = Puppet::FileServing::Metadata.new("/my/file")
    @metadata.stubs(:md5_file).returns(@checksum)
    @metadata.collect
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
    @metadata.checksum.should == "{md5}#{@checksum}"
  end

  describe "when managing files" do
    it "should default to a checksum of type MD5" do
      @metadata.checksum.should == "{md5}#{@checksum}"
    end

    it "should give a mtime checksum when checksum_type is set" do
      time = Time.now
      @metadata.checksum_type = "mtime"
      @metadata.expects(:mtime_file).returns(@time)
      @metadata.collect
      @metadata.checksum.should == "{mtime}#{@time}"
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
    end

    it "should only use checksums of type 'ctime' for directories" do
      @metadata.collect
      @metadata.checksum.should == "{ctime}#{@time}"
    end

    it "should only use checksums of type 'ctime' for directories even if checksum_type set" do
      @metadata.checksum_type = "mtime"
      @metadata.expects(:mtime_file).never
      @metadata.collect
      @metadata.checksum.should == "{ctime}#{@time}"
    end

    it "should produce tab-separated mode, type, owner, group, and checksum for xmlrpc" do
      @metadata.collect
      @metadata.attributes_with_tabs.should == "#{0755.to_s}\tdirectory\t10\t20\t{ctime}#{@time.to_s}"
    end
  end

  describe "when managing links" do
    before do
      @stat.stubs(:ftype).returns("link")
      File.expects(:readlink).with("/my/file").returns("/path/to/link")
      @metadata.collect

      @checksum = Digest::MD5.hexdigest("some content\n") # Remove these when :managed links are no longer checksumed.
      @file.stubs(:md5_file).returns(@checksum)           #
    end

    it "should read links instead of returning their checksums" do
      @metadata.destination.should == "/path/to/link"
    end

    pending "should produce tab-separated mode, type, owner, group, and destination for xmlrpc" do
      # "We'd like this to be true, but we need to always collect the checksum because in the server/client/server round trip we lose the distintion between manage and follow."
      @metadata.attributes_with_tabs.should == "#{0755}\tlink\t10\t20\t/path/to/link"
    end

    it "should produce tab-separated mode, type, owner, group, checksum, and destination for xmlrpc" do
      @metadata.attributes_with_tabs.should == "#{0755}\tlink\t10\t20\t{md5}eb9c2bf0eb63f3a7bc0ea37ef18aeba5\t/path/to/link"
    end
  end
end

describe Puppet::FileServing::Metadata, " when pointing to a link" do
  describe "when links are managed" do
    before do
      @file = Puppet::FileServing::Metadata.new("/base/path/my/file", :links => :manage)
      File.expects(:lstat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "link", :mode => 0755)
      File.expects(:readlink).with("/base/path/my/file").returns "/some/other/path"

      @checksum = Digest::MD5.hexdigest("some content\n") # Remove these when :managed links are no longer checksumed.
      @file.stubs(:md5_file).returns(@checksum)           #
    end
    it "should store the destination of the link in :destination if links are :manage" do
      @file.collect
      @file.destination.should == "/some/other/path"
    end
    pending "should not collect the checksum if links are :manage" do
      # We'd like this to be true, but we need to always collect the checksum because in the server/client/server round trip we lose the distintion between manage and follow.
      @file.collect
      @file.checksum.should be_nil
    end
    it "should collect the checksum if links are :manage" do # see pending note above
      @file.collect
      @file.checksum.should == "{md5}#{@checksum}"
    end
  end

  describe "when links are followed" do
    before do
      @file = Puppet::FileServing::Metadata.new("/base/path/my/file", :links => :follow)
      File.expects(:stat).with("/base/path/my/file").returns stub("stat", :uid => 1, :gid => 2, :ftype => "file", :mode => 0755)
      File.expects(:readlink).with("/base/path/my/file").never
      @checksum = Digest::MD5.hexdigest("some content\n")
      @file.stubs(:md5_file).returns(@checksum)
    end
    it "should not store the destination of the link in :destination if links are :follow" do
      @file.collect
      @file.destination.should be_nil
    end
    it "should collect the checksum if links are :follow" do
      @file.collect
      @file.checksum.should == "{md5}#{@checksum}"
    end
  end
end
