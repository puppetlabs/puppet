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

  describe "the suntab filetype" do
    before :each do
      @type = Puppet::Util::FileType.filetype(:suntab)
      @cron = @type.new('no_such_user')
    end

    let :suntab do
      File.read(my_fixture('suntab_output'))
    end

    it "should exist" do
      @type.should_not be_nil
    end

    describe "#read" do
      it "should run crontab -l as the target user" do
        Puppet::Util.expects(:execute).with(['crontab', '-l'], :failonfail => true, :combine => true, :uid => 'no_such_user').returns suntab
        @cron.read.should == suntab
      end

      it "should not switch user if current user is the target user" do
        Puppet::Util.expects(:uid).with('no_such_user').returns 9000
        Puppet::Util::SUIDManager.expects(:uid).returns 9000
        Puppet::Util.expects(:execute).with(['crontab', '-l'], :failonfail => true, :combine => true).returns suntab
        @cron.read.should == suntab
      end

      # possible crontab output was taken from here:
      # http://docs.oracle.com/cd/E19082-01/819-2380/sysrescron-60/index.html
      it "should treat an absent crontab as empty" do
        Puppet::Util.expects(:execute).with(['crontab', '-l'], :failonfail => true, :combine => true, :uid => 'no_such_user').raises(Puppet::ExecutionFailure, 'crontab: can\'t open your crontab file')
        @cron.read.should == ''
      end

      it "should raise an error if the user is not authorized to use cron" do
        Puppet::Util.expects(:execute).with(['crontab', '-l'], :failonfail => true, :combine => true, :uid => 'no_such_user').raises(Puppet::ExecutionFailure, 'crontab: you are not authorized to use cron. Sorry.')
        expect { @cron.read }.to raise_error Puppet::Error, /User no_such_user not authorized to use cron/
      end
    end

    describe "#remove" do
      it "should run crontab -r as the target user" do
        Puppet::Util.expects(:execute).with(['crontab', '-r'], :failonfail => true, :combine => true, :uid => 'no_such_user')
        @cron.remove
      end

      it "should not switch user if current user is the target user" do
        Puppet::Util.expects(:uid).with('no_such_user').returns 9000
        Puppet::Util::SUIDManager.expects(:uid).returns 9000
        Puppet::Util.expects(:execute).with(['crontab','-r'], :failonfail => true, :combine => true)
        @cron.remove
      end
    end

    describe "#write" do
      before :each do
        @tmp_cron = Tempfile.new("puppet_suntab_spec")
        @tmp_cron_path = @tmp_cron.path
        Puppet::Util.stubs(:uid).with('no_such_user').returns 9000
        Tempfile.expects(:new).with("puppet_suntab").returns @tmp_cron
      end

      after :each do
        File.should_not be_exist @tmp_cron_path
      end

      it "should run crontab as the target user on a temporary file" do
        File.expects(:chown).with(9000, nil, @tmp_cron_path)
        Puppet::Util.expects(:execute).with(["crontab", @tmp_cron_path], :failonfail => true, :combine => true, :uid => 'no_such_user')

        @tmp_cron.expects(:print).with("foo\n")
        @cron.write "foo\n"
      end

      it "should not switch user if current user is the target user" do
        Puppet::Util::SUIDManager.expects(:uid).returns 9000
        File.expects(:chown).with(9000, nil, @tmp_cron_path)
        Puppet::Util.expects(:execute).with(["crontab", @tmp_cron_path], :failonfail => true, :combine => true)
        @tmp_cron.expects(:print).with("foo\n")
        @cron.write "foo\n"
      end
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
