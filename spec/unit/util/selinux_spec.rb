require 'spec_helper'

require 'pathname'
require 'puppet/util/selinux'

describe Puppet::Util::SELinux do
  include Puppet::Util::SELinux

  let(:selinux) { double('selinux', is_selinux_enabled: false) }

  before :each do
    stub_const('Selinux', selinux)
  end

  describe "selinux_support?" do
    it "should return true if this system has SELinux enabled" do
      expect(Selinux).to receive(:is_selinux_enabled).and_return(1)
      expect(selinux_support?).to eq(true)
    end

    it "should return false if this system has SELinux disabled" do
      expect(Selinux).to receive(:is_selinux_enabled).and_return(0)
      expect(selinux_support?).to eq(false)
    end

    it "should return false if this system lacks SELinux" do
      hide_const('Selinux')
      expect(selinux_support?).to eq(false)
    end

    it "should return nil if /proc/mounts does not exist" do
      allow(File).to receive(:open).with("/proc/mounts").and_raise("No such file or directory - /proc/mounts")
      expect(read_mounts).to eq(nil)
    end
  end

  describe "read_mounts" do
    before :each do
      fh = double('fh', :close => nil)
      allow(File).to receive(:open).and_call_original()
      allow(File).to receive(:open).with("/proc/mounts").and_return(fh)
      times_fh_called = 0
      expect(fh).to receive(:read_nonblock) do
        times_fh_called += 1
        raise EOFError if times_fh_called > 1

        "rootfs / rootfs rw 0 0\n/dev/root / ext3 rw,relatime,errors=continue,user_xattr,acl,data=ordered 0 0\n/dev /dev tmpfs rw,relatime,mode=755 0 0\n/proc /proc proc rw,relatime 0 0\n/sys /sys sysfs rw,relatime 0 0\n192.168.1.1:/var/export /mnt/nfs nfs rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,nointr,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.1.1,mountvers=3,mountproto=udp,addr=192.168.1.1 0 0\n"
      end.twice()
    end

    it "should parse the contents of /proc/mounts" do
      result = read_mounts
      expect(result).to  eq({
        '/' => 'ext3',
        '/sys' => 'sysfs',
        '/mnt/nfs' => 'nfs',
        '/proc' => 'proc',
        '/dev' => 'tmpfs' })
    end
  end

  describe "filesystem detection" do
    before :each do
      allow(self).to receive(:read_mounts).and_return({
        '/'        => 'ext3',
        '/sys'     => 'sysfs',
        '/mnt/nfs' => 'nfs',
        '/proc'    => 'proc',
        '/dev'     => 'tmpfs' })
    end

    it "should match a path on / to ext3" do
      expect(find_fs('/etc/puppetlabs/puppet/testfile')).to eq("ext3")
    end

    it "should match a path on /mnt/nfs to nfs" do
      expect(find_fs('/mnt/nfs/testfile/foobar')).to eq("nfs")
    end

    it "should return true for a capable filesystem" do
      expect(selinux_label_support?('/etc/puppetlabs/puppet/testfile')).to be_truthy
    end

    it "should return true if tmpfs" do
      expect(selinux_label_support?('/dev/shm/testfile')).to be_truthy
    end

    it "should return false for a noncapable filesystem" do
      expect(selinux_label_support?('/mnt/nfs/testfile')).to be_falsey
    end

    it "(#8714) don't follow symlinks when determining file systems", :unless => Puppet::Util::Platform.windows? do
      scratch = Pathname(PuppetSpec::Files.tmpdir('selinux'))

      allow(self).to receive(:read_mounts).and_return({
        '/'             => 'ext3',
        scratch + 'nfs' => 'nfs',
      })

      (scratch + 'foo').make_symlink('nfs/bar')
      expect(selinux_label_support?(scratch + 'foo')).to be_truthy
    end

    it "should handle files that don't exist" do
      scratch = Pathname(PuppetSpec::Files.tmpdir('selinux'))
      expect(selinux_label_support?(scratch + 'nonesuch')).to be_truthy
    end
  end

  describe "get_selinux_current_context" do
    it "should return nil if no SELinux support" do
      expect(self).to receive(:selinux_support?).and_return(false)
      expect(get_selinux_current_context("/foo")).to be_nil
    end

    it "should return a context" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lgetfilecon).with("/foo").and_return([0, "user_u:role_r:type_t:s0"])
        expect(get_selinux_current_context("/foo")).to eq("user_u:role_r:type_t:s0")
      end
    end

    it "should return nil if lgetfilecon fails" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lgetfilecon).with("/foo").and_return(-1)
        expect(get_selinux_current_context("/foo")).to be_nil
      end
    end
  end

  describe "get_selinux_default_context" do
    it "should return nil if no SELinux support" do
      expect(self).to receive(:selinux_support?).and_return(false)
      expect(get_selinux_default_context("/foo")).to be_nil
    end

    it "should return a context if a default context exists" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        fstat = double('File::Stat', :mode => 0)
        expect(Puppet::FileSystem).to receive(:lstat).with('/foo').and_return(fstat)
        expect(self).to receive(:find_fs).with("/foo").and_return("ext3")
        expect(Selinux).to receive(:matchpathcon).with("/foo", 0).and_return([0, "user_u:role_r:type_t:s0"])

        expect(get_selinux_default_context("/foo")).to eq("user_u:role_r:type_t:s0")
      end
    end

    it "handles permission denied errors by issuing a warning" do
      without_partial_double_verification do
        allow(self).to receive(:selinux_support?).and_return(true)
        allow(self).to receive(:selinux_label_support?).and_return(true)
        allow(Selinux).to receive(:matchpathcon).with("/root/chuj", 0).and_return(-1)
        allow(self).to receive(:file_lstat).with("/root/chuj").and_raise(Errno::EACCES, "/root/chuj")

        expect(get_selinux_default_context("/root/chuj")).to be_nil
      end
    end

    it "backward compatibly handles no such file or directory errors by issuing a warning when resource_ensure not set" do
      without_partial_double_verification do
        allow(self).to receive(:selinux_support?).and_return(true)
        allow(self).to receive(:selinux_label_support?).and_return(true)
        allow(Selinux).to receive(:matchpathcon).with("/root/chuj", 0).and_return(-1)
        allow(self).to receive(:file_lstat).with("/root/chuj").and_raise(Errno::ENOENT, "/root/chuj")

        expect(get_selinux_default_context("/root/chuj")).to be_nil
      end
    end

    it "should determine mode based on resource ensure when set to file" do
      without_partial_double_verification do
        allow(self).to receive(:selinux_support?).and_return(true)
        allow(self).to receive(:selinux_label_support?).and_return(true)
        allow(Selinux).to receive(:matchpathcon).with("/root/chuj", 32768).and_return(-1)
        allow(self).to receive(:file_lstat).with("/root/chuj").and_raise(Errno::ENOENT, "/root/chuj")

        expect(get_selinux_default_context("/root/chuj", "present")).to be_nil
        expect(get_selinux_default_context("/root/chuj", "file")).to be_nil
      end
    end

    it "should determine mode based on resource ensure when set to dir" do
      without_partial_double_verification do
        allow(self).to receive(:selinux_support?).and_return(true)
        allow(self).to receive(:selinux_label_support?).and_return(true)
        allow(Selinux).to receive(:matchpathcon).with("/root/chuj", 16384).and_return(-1)
        allow(self).to receive(:file_lstat).with("/root/chuj").and_raise(Errno::ENOENT, "/root/chuj")

        expect(get_selinux_default_context("/root/chuj", "directory")).to be_nil
      end
    end

    it "should determine mode based on resource ensure when set to link" do
      without_partial_double_verification do
        allow(self).to receive(:selinux_support?).and_return(true)
        allow(self).to receive(:selinux_label_support?).and_return(true)
        allow(Selinux).to receive(:matchpathcon).with("/root/chuj", 40960).and_return(-1)
        allow(self).to receive(:file_lstat).with("/root/chuj").and_raise(Errno::ENOENT, "/root/chuj")

        expect(get_selinux_default_context("/root/chuj", "link")).to be_nil
      end
    end

    it "should determine mode based on resource ensure when set to unknown" do
      without_partial_double_verification do
        allow(self).to receive(:selinux_support?).and_return(true)
        allow(self).to receive(:selinux_label_support?).and_return(true)
        allow(Selinux).to receive(:matchpathcon).with("/root/chuj", 0).and_return(-1)
        allow(self).to receive(:file_lstat).with("/root/chuj").and_raise(Errno::ENOENT, "/root/chuj")

        expect(get_selinux_default_context("/root/chuj", "unknown")).to be_nil
      end
    end

    it "should return nil if matchpathcon returns failure" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        fstat = double('File::Stat', :mode => 0)
        expect(Puppet::FileSystem).to receive(:lstat).with('/foo').and_return(fstat)
        expect(self).to receive(:find_fs).with("/foo").and_return("ext3")
        expect(Selinux).to receive(:matchpathcon).with("/foo", 0).and_return(-1)

        expect(get_selinux_default_context("/foo")).to be_nil
      end
    end

    it "should return nil if selinux_label_support returns false" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(self).to receive(:find_fs).with("/foo").and_return("nfs")
        expect(get_selinux_default_context("/foo")).to be_nil
      end
    end
  end

  describe "parse_selinux_context" do
    it "should return nil if no context is passed" do
      expect(parse_selinux_context(:seluser, nil)).to be_nil
    end

    it "should return nil if the context is 'unlabeled'" do
      expect(parse_selinux_context(:seluser, "unlabeled")).to be_nil
    end

    it "should return the user type when called with :seluser" do
      expect(parse_selinux_context(:seluser, "user_u:role_r:type_t:s0")).to eq("user_u")
      expect(parse_selinux_context(:seluser, "user-withdash_u:role_r:type_t:s0")).to eq("user-withdash_u")
    end

    it "should return the role type when called with :selrole" do
      expect(parse_selinux_context(:selrole, "user_u:role_r:type_t:s0")).to eq("role_r")
      expect(parse_selinux_context(:selrole, "user_u:role-withdash_r:type_t:s0")).to eq("role-withdash_r")
    end

    it "should return the type type when called with :seltype" do
      expect(parse_selinux_context(:seltype, "user_u:role_r:type_t:s0")).to eq("type_t")
      expect(parse_selinux_context(:seltype, "user_u:role_r:type-withdash_t:s0")).to eq("type-withdash_t")
    end

    describe "with spaces in the components" do
      it "should raise when user contains a space" do
        expect{parse_selinux_context(:seluser, "user with space_u:role_r:type_t:s0")}.to raise_error Puppet::Error
      end

      it "should raise when role contains a space" do
        expect{parse_selinux_context(:selrole, "user_u:role with space_r:type_t:s0")}.to raise_error Puppet::Error
      end

      it "should raise when type contains a space" do
        expect{parse_selinux_context(:seltype, "user_u:role_r:type with space_t:s0")}.to raise_error Puppet::Error
      end

      it "should return the range when range contains a space" do
        expect(parse_selinux_context(:selrange, "user_u:role_r:type_t:s0 s1")).to eq("s0 s1")
      end
    end

    it "should return nil for :selrange when no range is returned" do
      expect(parse_selinux_context(:selrange, "user_u:role_r:type_t")).to be_nil
    end

    it "should return the range type when called with :selrange" do
      expect(parse_selinux_context(:selrange, "user_u:role_r:type_t:s0")).to eq("s0")
      expect(parse_selinux_context(:selrange, "user_u:role_r:type-withdash_t:s0")).to eq("s0")
    end

    describe "with a variety of SELinux range formats" do
      ['s0', 's0:c3', 's0:c3.c123', 's0:c3,c5,c8', 'TopSecret', 'TopSecret,Classified', 'Patient_Record'].each do |range|
        it "should parse range '#{range}'" do
          expect(parse_selinux_context(:selrange, "user_u:role_r:type_t:#{range}")).to eq(range)
        end
      end
    end
  end

  describe "set_selinux_context" do
    before :each do
      fh = double('fh', :close => nil)
      allow(File).to receive(:open).with("/proc/mounts").and_return(fh)
      times_fh_called = 0
      allow(fh).to receive(:read_nonblock) do
        times_fh_called += 1
        raise EOFError if times_fh_called > 1

        "rootfs / rootfs rw 0 0\n/dev/root / ext3 rw,relatime,errors=continue,user_xattr,acl,data=ordered 0 0\n"+
        "/dev /dev tmpfs rw,relatime,mode=755 0 0\n/proc /proc proc rw,relatime 0 0\n"+
        "/sys /sys sysfs rw,relatime 0 0\n"
      end
    end

    it "should return nil if there is no SELinux support" do
      expect(self).to receive(:selinux_support?).and_return(false)
      expect(set_selinux_context("/foo", "user_u:role_r:type_t:s0")).to be_nil
    end

    it "should return nil if selinux_label_support returns false" do
      expect(self).to receive(:selinux_support?).and_return(true)
      expect(self).to receive(:selinux_label_support?).with("/foo").and_return(false)
      expect(set_selinux_context("/foo", "user_u:role_r:type_t:s0")).to be_nil
    end

    it "should use lsetfilecon to set a context" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").and_return(0)
        expect(set_selinux_context("/foo", "user_u:role_r:type_t:s0")).to be_truthy
      end
    end

    it "should use lsetfilecon to set user_u user context" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lgetfilecon).with("/foo").and_return([0, "foo:role_r:type_t:s0"])
        expect(Selinux).to receive(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").and_return(0)
        expect(set_selinux_context("/foo", "user_u", :seluser)).to be_truthy
      end
    end

    it "should use lsetfilecon to set role_r role context" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lgetfilecon).with("/foo").and_return([0, "user_u:foo:type_t:s0"])
        expect(Selinux).to receive(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").and_return(0)
        expect(set_selinux_context("/foo", "role_r", :selrole)).to be_truthy
      end
    end

    it "should use lsetfilecon to set type_t type context" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lgetfilecon).with("/foo").and_return([0, "user_u:role_r:foo:s0"])
        expect(Selinux).to receive(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0").and_return(0)
        expect(set_selinux_context("/foo", "type_t", :seltype)).to be_truthy
      end
    end

    it "should use lsetfilecon to set s0:c3,c5 range context" do
      without_partial_double_verification do
        expect(self).to receive(:selinux_support?).and_return(true)
        expect(Selinux).to receive(:lgetfilecon).with("/foo").and_return([0, "user_u:role_r:type_t:s0"])
        expect(Selinux).to receive(:lsetfilecon).with("/foo", "user_u:role_r:type_t:s0:c3,c5").and_return(0)
        expect(set_selinux_context("/foo", "s0:c3,c5", :selrange)).to be_truthy
      end
    end
  end

  describe "set_selinux_default_context" do
    it "should return nil if there is no SELinux support" do
      expect(self).to receive(:selinux_support?).and_return(false)
      expect(set_selinux_default_context("/foo")).to be_nil
    end

    it "should return nil if no default context exists" do
      expect(self).to receive(:get_selinux_default_context).with("/foo", nil).and_return(nil)
      expect(set_selinux_default_context("/foo")).to be_nil
    end

    it "should do nothing and return nil if the current context matches the default context" do
      expect(self).to receive(:get_selinux_default_context).with("/foo", nil).and_return("user_u:role_r:type_t")
      expect(self).to receive(:get_selinux_current_context).with("/foo").and_return("user_u:role_r:type_t")
      expect(set_selinux_default_context("/foo")).to be_nil
    end

    it "should set and return the default context if current and default do not match" do
      expect(self).to receive(:get_selinux_default_context).with("/foo", nil).and_return("user_u:role_r:type_t")
      expect(self).to receive(:get_selinux_current_context).with("/foo").and_return("olduser_u:role_r:type_t")
      expect(self).to receive(:set_selinux_context).with("/foo", "user_u:role_r:type_t").and_return(true)
      expect(set_selinux_default_context("/foo")).to eq("user_u:role_r:type_t")
    end
  end

  describe "get_create_mode" do
    it "should return 0 if the resource is absent" do
      expect(get_create_mode("absent")).to eq(0)
    end

    it "should return mode with file type set to S_IFREG when resource is file" do
      expect(get_create_mode("present")).to eq(32768)
      expect(get_create_mode("file")).to eq(32768)
    end

    it "should return mode with file type set to S_IFDIR when resource is dir" do
      expect(get_create_mode("directory")).to eq(16384)
    end

    it "should return mode with file type set to S_IFLNK when resource is link" do
      expect(get_create_mode("link")).to eq(40960)
    end

    it "should return 0 for everything else" do
      expect(get_create_mode("unknown")).to eq(0)
    end
  end
end
