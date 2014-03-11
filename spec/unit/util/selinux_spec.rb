#! /usr/bin/env ruby
require 'spec_helper'

require 'pathname'
require 'puppet/util/selinux'
include Puppet::Util::SELinux

unless defined?(Selinux)
  module Selinux
    def self.is_selinux_enabled
      false
    end
  end
end

describe Puppet::Util::SELinux do

  describe "selinux_support?" do
    before do
    end
    it "should return :true if this system has SELinux enabled" do
      Selinux.expects(:is_selinux_enabled).returns 1
      selinux_support?.should be_true
    end

    it "should return :false if this system lacks SELinux" do
      Selinux.expects(:is_selinux_enabled).returns 0
      selinux_support?.should be_false
    end

    it "should return nil if /proc/mounts does not exist" do
      File.stubs(:open).with("/proc/mounts").raises("No such file or directory - /proc/mounts")
      read_mounts.should == nil
    end
  end

  describe "read_mounts" do
    before :each do
      fh = stub 'fh', :close => nil
      File.stubs(:open).with("/proc/mounts").returns fh
      fh.expects(:read_nonblock).times(2).returns("rootfs / rootfs rw 0 0\n/dev/root / ext3 rw,relatime,errors=continue,user_xattr,acl,data=ordered 0 0\n/dev /dev tmpfs rw,relatime,mode=755 0 0\n/proc /proc proc rw,relatime 0 0\n/sys /sys sysfs rw,relatime 0 0\n192.168.1.1:/var/export /mnt/nfs nfs rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,nointr,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.1.1,mountvers=3,mountproto=udp,addr=192.168.1.1 0 0\n").then.raises EOFError
    end

    it "should parse the contents of /proc/mounts" do
      read_mounts.should  == {
        '/' => 'ext3',
        '/sys' => 'sysfs',
        '/mnt/nfs' => 'nfs',
        '/proc' => 'proc',
        '/dev' => 'tmpfs' }
    end
  end

  describe "filesystem detection" do
    before :each do
      self.stubs(:read_mounts).returns({
        '/'        => 'ext3',
        '/sys'     => 'sysfs',
        '/mnt/nfs' => 'nfs',
        '/proc'    => 'proc',
        '/dev'     => 'tmpfs' })
    end

    it "should match a path on / to ext3" do
      find_fs('/etc/puppet/testfile').should == "ext3"
    end

    it "should match a path on /mnt/nfs to nfs" do
      find_fs('/mnt/nfs/testfile/foobar').should == "nfs"
    end

    it "should return true for a capable filesystem" do
      selinux_label_support?('/etc/puppet/testfile').should be_true
    end

    it "should return false for a noncapable filesystem" do
      selinux_label_support?('/mnt/nfs/testfile').should be_false
    end

    it "(#8714) don't follow symlinks when determining file systems", :unless => Puppet.features.microsoft_windows? do
      scratch = Pathname(PuppetSpec::Files.tmpdir('selinux'))

      self.stubs(:read_mounts).returns({
          '/'             => 'ext3',
          scratch + 'nfs' => 'nfs',
        })

      (scratch + 'foo').make_symlink('nfs/bar')
      selinux_label_support?(scratch + 'foo').should be_true
    end

    it "should handle files that don't exist" do
      scratch = Pathname(PuppetSpec::Files.tmpdir('selinux'))
      selinux_label_support?(scratch + 'nonesuch').should be_true
    end
  end

  describe "get_selinux_current_context" do
    it "should return nil if no SELinux support" do
      self.expects(:selinux_support?).returns false
      get_selinux_current_context("/foo").should be_nil
    end

    it "should return a context" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lgetfilecon).with("/foo").returns [0, "user_u:role_r:type_t:s0"]
      get_selinux_current_context("/foo").should == "user_u:role_r:type_t:s0"
    end

    it "should return nil if lgetfilecon fails" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lgetfilecon).with("/foo").returns -1
      get_selinux_current_context("/foo").should be_nil
    end
  end

  describe "get_selinux_default_context" do
    it "should return nil if no SELinux support" do
      self.expects(:selinux_support?).returns false
      get_selinux_default_context("/foo").should be_nil
    end

    it "should return a context if a default context exists" do
      self.expects(:selinux_support?).returns true
      fstat = stub 'File::Stat', :mode => 0
      Puppet::FileSystem.expects(:lstat).with('/foo').returns(fstat)
      self.expects(:find_fs).with("/foo").returns "ext3"
      Selinux.expects(:matchpathcon).with("/foo", 0).returns [0, "user_u:role_r:type_t:s0"]

      get_selinux_default_context("/foo").should == "user_u:role_r:type_t:s0"
    end

    it "handles permission denied errors by issuing a warning" do
      self.stubs(:selinux_support?).returns true
      self.stubs(:selinux_label_support?).returns true
      Selinux.stubs(:matchpathcon).with("/root/chuj", 0).returns(-1)
      self.stubs(:file_lstat).with("/root/chuj").raises(Errno::EACCES, "/root/chuj")

      get_selinux_default_context("/root/chuj").should be_nil
    end

    it "handles no such file or directory errors by issuing a warning" do
      self.stubs(:selinux_support?).returns true
      self.stubs(:selinux_label_support?).returns true
      Selinux.stubs(:matchpathcon).with("/root/chuj", 0).returns(-1)
      self.stubs(:file_lstat).with("/root/chuj").raises(Errno::ENOENT, "/root/chuj")

      get_selinux_default_context("/root/chuj").should be_nil
    end

    it "should return nil if matchpathcon returns failure" do
      self.expects(:selinux_support?).returns true
      fstat = stub 'File::Stat', :mode => 0
      Puppet::FileSystem.expects(:lstat).with('/foo').returns(fstat)
      self.expects(:find_fs).with("/foo").returns "ext3"
      Selinux.expects(:matchpathcon).with("/foo", 0).returns -1

      get_selinux_default_context("/foo").should be_nil
    end

    it "should return nil if selinux_label_support returns false" do
      self.expects(:selinux_support?).returns true
      self.expects(:find_fs).with("/foo").returns "nfs"
      get_selinux_default_context("/foo").should be_nil
    end

  end

  describe "parse_selinux_context" do
    it "should return nil if no context is passed" do
      parse_selinux_context(:seluser, nil).should be_nil
    end

    it "should return nil if the context is 'unlabeled'" do
      parse_selinux_context(:seluser, "unlabeled").should be_nil
    end

    it "should return the user type when called with :seluser" do
      parse_selinux_context(:seluser, "user_u:role_r:type_t:s0").should == "user_u"
    end

    it "should return the role type when called with :selrole" do
      parse_selinux_context(:selrole, "user_u:role_r:type_t:s0").should == "role_r"
    end

    it "should return the type type when called with :seltype" do
      parse_selinux_context(:seltype, "user_u:role_r:type_t:s0").should == "type_t"
    end

    it "should return nil for :selrange when no range is returned" do
      parse_selinux_context(:selrange, "user_u:role_r:type_t").should be_nil
    end

    it "should return the range type when called with :selrange" do
      parse_selinux_context(:selrange, "user_u:role_r:type_t:s0").should == "s0"
    end

    describe "with a variety of SELinux range formats" do
      ['s0', 's0:c3', 's0:c3.c123', 's0:c3,c5,c8', 'TopSecret', 'TopSecret,Classified', 'Patient_Record'].each do |range|
        it "should parse range '#{range}'" do
          parse_selinux_context(:selrange, "user_u:role_r:type_t:#{range}").should == range
        end
      end
    end
  end

  describe "set_selinux_context" do
    before :each do
      fh = stub 'fh', :close => nil
      File.stubs(:open).with("/proc/mounts").returns fh
      fh.stubs(:read_nonblock).returns(
        "rootfs / rootfs rw 0 0\n/dev/root / ext3 rw,relatime,errors=continue,user_xattr,acl,data=ordered 0 0\n"+
        "/dev /dev tmpfs rw,relatime,mode=755 0 0\n/proc /proc proc rw,relatime 0 0\n"+
        "/sys /sys sysfs rw,relatime 0 0\n"
        ).then.raises EOFError
    end

    it "should return nil if there is no SELinux support" do
      self.expects(:selinux_support?).returns false
      set_selinux_context("/foo", "user_u:role_r:type_t:s0").should be_nil
    end

    it "should return nil if selinux_label_support returns false" do
      self.expects(:selinux_support?).returns true
      self.expects(:selinux_label_support?).with("/foo").returns false
      set_selinux_context("/foo", "user_u:role_r:type_t:s0").should be_nil
    end

    it "should use lsetfilecon to set a context" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").returns 0
      set_selinux_context("/foo", "user_u:role_r:type_t:s0").should be_true
    end

    it "should use lsetfilecon to set user_u user context" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lgetfilecon).with("/foo").returns [0, "foo:role_r:type_t:s0"]
      Selinux.expects(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").returns 0
      set_selinux_context("/foo", "user_u", :seluser).should be_true
    end

    it "should use lsetfilecon to set role_r role context" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lgetfilecon).with("/foo").returns [0, "user_u:foo:type_t:s0"]
      Selinux.expects(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").returns 0
      set_selinux_context("/foo", "role_r", :selrole).should be_true
    end

    it "should use lsetfilecon to set type_t type context" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lgetfilecon).with("/foo").returns [0, "user_u:role_r:foo:s0"]
      Selinux.expects(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").returns 0
      set_selinux_context("/foo", "type_t", :seltype).should be_true
    end

    it "should use lsetfilecon to set s0:c3,c5 range context" do
      self.expects(:selinux_support?).returns true
      Selinux.expects(:lgetfilecon).with("/foo").returns [0, "user_u:role_r:type_t:s0"]
      Selinux.expects(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0:c3,c5").returns 0
      set_selinux_context("/foo", "s0:c3,c5", :selrange).should be_true
    end
  end

  describe "set_selinux_default_context" do
    it "should return nil if there is no SELinux support" do
      self.expects(:selinux_support?).returns false
      set_selinux_default_context("/foo").should be_nil
    end

    it "should return nil if no default context exists" do
      self.expects(:get_selinux_default_context).with("/foo").returns nil
      set_selinux_default_context("/foo").should be_nil
    end

    it "should do nothing and return nil if the current context matches the default context" do
      self.expects(:get_selinux_default_context).with("/foo").returns "user_u:role_r:type_t"
      self.expects(:get_selinux_current_context).with("/foo").returns "user_u:role_r:type_t"
      set_selinux_default_context("/foo").should be_nil
    end

    it "should set and return the default context if current and default do not match" do
      self.expects(:get_selinux_default_context).with("/foo").returns "user_u:role_r:type_t"
      self.expects(:get_selinux_current_context).with("/foo").returns "olduser_u:role_r:type_t"
      self.expects(:set_selinux_context).with("/foo", "user_u:role_r:type_t").returns true
      set_selinux_default_context("/foo").should == "user_u:role_r:type_t"
    end
  end

end
