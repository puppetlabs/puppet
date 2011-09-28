#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/adsi'

if Puppet.features.microsoft_windows?
  class WindowsSecurityTester
    require 'puppet/util/windows/security'
    include Puppet::Util::Windows::Security
  end
end

describe "Puppet::Util::Windows::Security", :if => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  before :all do
    @sids = {
      :current_user => Puppet::Util::ADSI.sid_for_account(Sys::Admin.get_login),
      :admin => Puppet::Util::ADSI.sid_for_account("Administrator"),
      :guest => Puppet::Util::ADSI.sid_for_account("Guest"),
      :users => Win32::Security::SID::BuiltinUsers,
      :power_users => Win32::Security::SID::PowerUsers,
    }
  end

  let (:sids) { @sids }
  let (:winsec) { WindowsSecurityTester.new }

  shared_examples_for "a securable object" do
    describe "for a normal user" do
      before :each do
        Puppet.features.stubs(:root?).returns(false)
      end

      after :each do
        winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)
      end

      describe "#owner=" do
        it "should allow setting to the current user" do
          winsec.set_owner(sids[:current_user], path)
        end

        it "should raise an exception when setting to a different user" do
          lambda { winsec.set_owner(sids[:guest], path) }.should raise_error(Puppet::Error, /This security ID may not be assigned as the owner of this object./)
        end
      end

      describe "#owner" do
        it "it should not be empty" do
          winsec.get_owner(path).should_not be_empty
        end

        it "should raise an exception if an invalid path is provided" do
          lambda { winsec.get_owner("c:\\doesnotexist.txt") }.should raise_error(Puppet::Error, /The system cannot find the file specified./)
        end
      end

      describe "#group=" do
        it "should allow setting to a group the current owner is a member of" do
          winsec.set_group(sids[:users], path)
        end

        # Unlike unix, if the user has permission to WRITE_OWNER, which the file owner has by default,
        # then they can set the primary group to a group that the user does not belong to.
        it "should allow setting to a group the current owner is not a member of" do
          winsec.set_group(sids[:power_users], path)
        end
      end

      describe "#group" do
        it "should not be empty" do
          winsec.get_group(path).should_not be_empty
        end

        it "should raise an exception if an invalid path is provided" do
          lambda { winsec.get_group("c:\\doesnotexist.txt") }.should raise_error(Puppet::Error, /The system cannot find the file specified./)
        end
      end

      describe "#mode=" do
        [0000, 0100, 0200, 0300, 0400, 0500, 0600, 0700].each do |mode|
          it "should enforce mode #{mode.to_s(8)}" do
            winsec.set_mode(mode, path)

            check_access(mode, path)
          end
        end

        it "should round-trip all 64 modes that do not require deny ACEs" do
          0.upto(7).each do |u|
            0.upto(u).each do |g|
              0.upto(g).each do |o|
                # if user is superset of group, and group superset of other, then
                # no deny ace is required, and mode can be converted to win32
                # access mask, and back to mode without loss of information
                # (provided the owner and group are not the same)
                next if ((u & g) != g) or ((g & o) != o)

                mode = (u << 6 | g << 3 | o << 0)
                winsec.set_mode(mode, path)
                winsec.get_mode(path).to_s(8).should == mode.to_s(8)
              end
            end
          end
        end

        describe "for modes that require deny aces" do
          it "should map everyone to group and owner" do
            winsec.set_mode(0426, path)
            winsec.get_mode(path).to_s(8).should == "666"
          end

          it "should combine user and group modes when owner and group sids are equal" do
            winsec.set_group(winsec.get_owner(path), path)

            winsec.set_mode(0410, path)
            winsec.get_mode(path).to_s(8).should == "550"
          end
        end

        describe "for read-only objects" do
          before :each do
            winsec.add_attributes(path, WindowsSecurityTester::FILE_ATTRIBUTE_READONLY)
            (winsec.get_attributes(path) & WindowsSecurityTester::FILE_ATTRIBUTE_READONLY).should be_nonzero
          end

          it "should make them writable if any sid has write permission" do
            winsec.set_mode(WindowsSecurityTester::S_IWUSR, path)
            (winsec.get_attributes(path) & WindowsSecurityTester::FILE_ATTRIBUTE_READONLY).should == 0
          end

          it "should leave them read-only if no sid has write permission" do
            winsec.set_mode(WindowsSecurityTester::S_IRUSR | WindowsSecurityTester::S_IXGRP, path)
            (winsec.get_attributes(path) & WindowsSecurityTester::FILE_ATTRIBUTE_READONLY).should be_nonzero
          end
        end

        it "should raise an exception if an invalid path is provided" do
          lambda { winsec.set_mode(sids[:guest], "c:\\doesnotexist.txt") }.should raise_error(Puppet::Error, /The system cannot find the file specified./)
        end
      end

      describe "#mode" do
        it "should report when extra aces are encounted" do
          winsec.set_acl(path, true) do |acl|
            [ 544, 545, 546, 547 ].each do |rid|
              winsec.add_access_allowed_ace(acl, WindowsSecurityTester::STANDARD_RIGHTS_ALL, "S-1-5-32-#{rid}")
            end
          end
          mode = winsec.get_mode(path)
          (mode & WindowsSecurityTester::S_IEXTRA).should_not == 0
        end

        it "should warn if a deny ace is encountered" do
          winsec.set_acl(path) do |acl|
            winsec.add_access_denied_ace(acl, WindowsSecurityTester::FILE_GENERIC_WRITE, sids[:guest])
            winsec.add_access_allowed_ace(acl, WindowsSecurityTester::STANDARD_RIGHTS_ALL | WindowsSecurityTester::SPECIFIC_RIGHTS_ALL, sids[:current_user])
          end

          Puppet.expects(:warning).with("Unsupported access control entry type: 0x1")

          winsec.get_mode(path)
        end

        it "should skip inherit-only ace" do
          winsec.set_acl(path) do |acl|
            winsec.add_access_allowed_ace(acl, WindowsSecurityTester::STANDARD_RIGHTS_ALL | WindowsSecurityTester::SPECIFIC_RIGHTS_ALL, sids[:current_user])
            winsec.add_access_allowed_ace(acl, WindowsSecurityTester::FILE_GENERIC_READ, Win32::Security::SID::Everyone, WindowsSecurityTester::INHERIT_ONLY_ACE | WindowsSecurityTester::OBJECT_INHERIT_ACE)
          end

          (winsec.get_mode(path) & WindowsSecurityTester::S_IRWXO).should == 0
        end

        it "should raise an exception if an invalid path is provided" do
          lambda { winsec.get_mode("c:\\doesnotexist.txt") }.should raise_error(Puppet::Error, /The system cannot find the file specified./)
        end
      end

      describe "inherited access control entries" do
        it "should be absent when the access control list is protected" do
          winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)
          (winsec.get_mode(path) & WindowsSecurityTester::S_IEXTRA).should == 0
        end

        it "should be present when the access control list is unprotected" do
          dir = tmpdir('win_sec_parent')

          # add a bunch of aces, make sure we can add to the directory
          allow = WindowsSecurityTester::STANDARD_RIGHTS_ALL | WindowsSecurityTester::SPECIFIC_RIGHTS_ALL
          inherit = WindowsSecurityTester::OBJECT_INHERIT_ACE | WindowsSecurityTester::CONTAINER_INHERIT_ACE

          winsec.set_acl(dir, true) do |acl|
            winsec.add_access_allowed_ace(acl, allow, "S-1-1-0", inherit) # everyone

            [ 544, 545, 546, 547 ].each do |rid|
              winsec.add_access_allowed_ace(acl, WindowsSecurityTester::STANDARD_RIGHTS_ALL, "S-1-5-32-#{rid}", inherit)
            end
          end

          # add a file
          child = File.join(dir, "child")
          File.new(child, "w").close

          # unprotect child, it should inherit from parent
          winsec.set_mode(WindowsSecurityTester::S_IRWXU, child, false)
          (winsec.get_mode(child) & WindowsSecurityTester::S_IEXTRA).should == WindowsSecurityTester::S_IEXTRA
        end
      end
    end

    describe "for an administrator", :if => Puppet.features.root? do
      before :each do
        winsec.set_owner(sids[:guest], path)
        winsec.set_group(sids[:guest], path)
        winsec.set_mode(WindowsSecurityTester::S_IRWXU | WindowsSecurityTester::S_IRWXG, path)
        lambda { File.open(path, 'r') }.should raise_error(Errno::EACCES)
      end

      after :each do
        winsec.set_owner(sids[:current_user], path)
        winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)
      end

      describe "#owner=" do
        it "should accept a user sid" do
          winsec.set_owner(sids[:admin], path)
          winsec.get_owner(path).should == sids[:admin]
        end

        it "should accept a group sid" do
          winsec.set_owner(sids[:power_users], path)
          winsec.get_owner(path).should == sids[:power_users]
        end

        it "should raise an exception if an invalid sid is provided" do
          lambda { winsec.set_owner("foobar", path) }.should raise_error(Puppet::Error, /Failed to convert string SID/)
        end

        it "should raise an exception if an invalid path is provided" do
          lambda { winsec.set_owner(sids[:guest], "c:\\doesnotexist.txt") }.should raise_error(Puppet::Error, /The system cannot find the file specified./)
        end
      end

      describe "#group=" do
        it "should accept a group sid" do
          winsec.set_group(sids[:power_users], path)
          winsec.get_group(path).should == sids[:power_users]
        end

        it "should accept a user sid" do
          winsec.set_group(sids[:admin], path)
          winsec.get_group(path).should == sids[:admin]
        end

        it "should allow owner and group to be the same sid" do
          winsec.set_owner(sids[:power_users], path)
          winsec.set_group(sids[:power_users], path)
          winsec.set_mode(0610, path)

          winsec.get_owner(path).should == sids[:power_users]
          winsec.get_group(path).should == sids[:power_users]
          # note group execute permission added to user ace, and then group rwx value
          # reflected to match
          winsec.get_mode(path).to_s(8).should == "770"
        end

        it "should raise an exception if an invalid sid is provided" do
          lambda { winsec.set_group("foobar", path) }.should raise_error(Puppet::Error, /Failed to convert string SID/)
        end

        it "should raise an exception if an invalid path is provided" do
          lambda { winsec.set_group(sids[:guest], "c:\\doesnotexist.txt") }.should raise_error(Puppet::Error, /The system cannot find the file specified./)
        end
      end

      describe "when the sid is NULL" do
        it "should retrieve an empty owner sid"
        it "should retrieve an empty group sid"
      end

      describe "when the sid refers to a deleted trustee" do
        it "should retrieve the user sid" do
          sid = nil
          user = Puppet::Util::ADSI::User.create("delete_me_user")
          user.commit
          begin
            sid = Sys::Admin::get_user(user.name).sid
            winsec.set_owner(sid, path)
            winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)
          ensure
            Puppet::Util::ADSI::User.delete(user.name)
          end

          winsec.get_owner(path).should == sid
          winsec.get_mode(path).should == WindowsSecurityTester::S_IRWXU
        end

        it "should retrieve the group sid" do
          sid = nil
          group = Puppet::Util::ADSI::Group.create("delete_me_group")
          group.commit
          begin
            sid = Sys::Admin::get_group(group.name).sid
            winsec.set_group(sid, path)
            winsec.set_mode(WindowsSecurityTester::S_IRWXG, path)
          ensure
            Puppet::Util::ADSI::Group.delete(group.name)
          end
          winsec.get_group(path).should == sid
          winsec.get_mode(path).should == WindowsSecurityTester::S_IRWXG
        end
      end

      describe "#mode" do
        it "should deny all access when the DACL is empty" do
          winsec.set_acl(path, true) { |acl| }

          winsec.get_mode(path).should == 0
        end

        # REMIND: ruby crashes when trying to set a NULL DACL
        # it "should allow all when it is nil" do
        #   winsec.set_owner(sids[:current_user], path)
        #   winsec.open_file(path, WindowsSecurityTester::READ_CONTROL | WindowsSecurityTester::WRITE_DAC) do |handle|
        #     winsec.set_security_info(handle, WindowsSecurityTester::DACL_SECURITY_INFORMATION | WindowsSecurityTester::PROTECTED_DACL_SECURITY_INFORMATION, nil)
        #   end
        #   winsec.get_mode(path).to_s(8).should == "777"
        # end
      end

      describe "#string_to_sid_ptr" do
        it "should raise an error if an invalid SID is specified" do
          expect do
            winsec.string_to_sid_ptr('foobar')
          end.to raise_error(Puppet::Util::Windows::Error) { |error| error.code.should == 1337 }
        end

        it "should yield if a block is given" do
          yielded = nil
          winsec.string_to_sid_ptr('S-1-1-0') do |sid|
            yielded = sid
          end
          yielded.should_not be_nil
        end

        it "should allow no block to be specified" do
          winsec.string_to_sid_ptr('S-1-1-0').should be_true
        end
      end
    end
  end

  describe "file" do
    let :path do
      path = tmpfile('win_sec_test_file')
      File.new(path, "w").close
      path
    end

    it_behaves_like "a securable object" do
      def check_access(mode, path)
        if (mode & WindowsSecurityTester::S_IRUSR).nonzero?
          check_read(path)
        else
          lambda { check_read(path) }.should raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IWUSR).nonzero?
          check_write(path)
        else
          lambda { check_write(path) }.should raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IXUSR).nonzero?
          lambda { check_execute(path) }.should raise_error(Errno::ENOEXEC)
        else
          lambda { check_execute(path) }.should raise_error(Errno::EACCES)
        end
      end

      def check_read(path)
        File.open(path, 'r').close
      end

      def check_write(path)
        File.open(path, 'w').close
      end

      def check_execute(path)
        Kernel.exec(path)
      end
    end

    describe "locked files" do
      let (:explorer) { File.join(Dir::WINDOWS, "explorer.exe") }

      it "should get the owner" do
        winsec.get_owner(explorer).should match /^S-1-5-/
      end

      it "should get the group" do
        winsec.get_group(explorer).should match /^S-1-5-/
      end

      it "should get the mode" do
        winsec.get_mode(explorer).should == (WindowsSecurityTester::S_IRWXU | WindowsSecurityTester::S_IRWXG | WindowsSecurityTester::S_IEXTRA)
      end
    end
  end

  describe "directory" do
    let :path do
      tmpdir('win_sec_test_dir')
    end

    it_behaves_like "a securable object" do
      def check_access(mode, path)
        if (mode & WindowsSecurityTester::S_IRUSR).nonzero?
          check_read(path)
        else
          lambda { check_read(path) }.should raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IWUSR).nonzero?
          check_write(path)
        else
          lambda { check_write(path) }.should raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IXUSR).nonzero?
          check_execute(path)
        else
          lambda { check_execute(path) }.should raise_error(Errno::EACCES)
        end
      end

      def check_read(path)
        Dir.entries(path)
      end

      def check_write(path)
        Dir.mkdir(File.join(path, "subdir"))
      end

      def check_execute(path)
        Dir.chdir(path) {|dir| }
      end
    end

    describe "inheritable aces" do
      it "should be applied to child objects" do
        mode640 = WindowsSecurityTester::S_IRUSR | WindowsSecurityTester::S_IWUSR | WindowsSecurityTester::S_IRGRP
        winsec.set_mode(mode640, path)

        newfile = File.join(path, "newfile.txt")
        File.new(newfile, "w").close

        newdir = File.join(path, "newdir")
        Dir.mkdir(newdir)

        [newfile, newdir].each do |p|
          winsec.get_mode(p).to_s(8).should == mode640.to_s(8)
        end
      end
    end
  end
end
