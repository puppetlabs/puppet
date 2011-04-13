#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/filetype'

# XXX Import all of the tests into this file.
describe Puppet::Util::FileType do
  describe "when backing up a file" do
    before do
      @file = Puppet::Util::FileType.filetype(:flat).new("/my/file")
    end

    it "should do nothing if the file does not exist" do
      File.expects(:exists?).with("/my/file").returns false
      @file.expects(:bucket).never
      @file.backup
    end

    it "should use its filebucket to backup the file if it exists" do
      File.expects(:exists?).with("/my/file").returns true

      bucket = mock 'bucket'
      bucket.expects(:backup).with("/my/file")

      @file.expects(:bucket).returns bucket
      @file.backup
    end

    it "should use the default filebucket" do
      bucket = mock 'bucket'
      bucket.expects(:bucket).returns "mybucket"

      Puppet::Type.type(:filebucket).expects(:mkdefaultbucket).returns bucket

      @file.bucket.should == "mybucket"
    end
  end

  describe "the flat filetype" do
    before do
      @type = Puppet::Util::FileType.filetype(:flat)
    end
    it "should exist" do
      @type.should_not be_nil
    end

    describe "when the file already exists" do
      it "should return the file's contents when asked to read it" do
        file = @type.new("/my/file")
        File.expects(:exist?).with("/my/file").returns true
        File.expects(:read).with("/my/file").returns "my text"

        file.read.should == "my text"
      end

      it "should unlink the file when asked to remove it" do
        file = @type.new("/my/file")
        File.expects(:exist?).with("/my/file").returns true
        File.expects(:unlink).with("/my/file")

        file.remove
      end
    end

    describe "when the file does not exist" do
      it "should return an empty string when asked to read the file" do
        file = @type.new("/my/file")
        File.expects(:exist?).with("/my/file").returns false

        file.read.should == ""
      end
    end

    describe "when writing the file" do
      before do
        @file = @type.new("/my/file")
        FileUtils.stubs(:cp)

        @tempfile = stub 'tempfile', :print => nil, :close => nil, :flush => nil, :path => "/other/file"
        Tempfile.stubs(:new).returns @tempfile
      end

      it "should first create a temp file and copy its contents over to the file location" do
        Tempfile.expects(:new).with("puppet").returns @tempfile
        @tempfile.expects(:print).with("my text")
        @tempfile.expects(:flush)
        @tempfile.expects(:close)
        FileUtils.expects(:cp).with(@tempfile.path, "/my/file")

        @file.write "my text"
      end

      it "should set the selinux default context on the file" do
        @file.expects(:set_selinux_default_context).with("/my/file")
        @file.write "eh"
      end
    end
  end
end
