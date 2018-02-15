#!/usr/bin/env ruby
require 'spec_helper'

if Puppet.features.microsoft_windows?
  class WindowsSecurityTester
    require 'puppet/util/windows/security'
    include Puppet::Util::Windows::Security
  end
end

describe "Puppet::Util::Windows::Security", :if => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  before :all do

    # necessary for localized name of guests
    guests_name = Puppet::Util::Windows::SID.sid_to_name('S-1-5-32-546')
    guests = Puppet::Util::Windows::ADSI::Group.new(guests_name)

    @sids = {
      :current_user => Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_user_name),
      :system => Puppet::Util::Windows::SID::LocalSystem,
      :administrators => Puppet::Util::Windows::SID::BuiltinAdministrators,
      :guest => Puppet::Util::Windows::SID.name_to_sid(guests.members[0]),
      :users => Puppet::Util::Windows::SID::BuiltinUsers,
      :power_users => Puppet::Util::Windows::SID::PowerUsers,
      :none => Puppet::Util::Windows::SID::Nobody,
      :everyone => Puppet::Util::Windows::SID::Everyone
    }
    # The TCP/IP NetBIOS Helper service (aka 'lmhosts') has ended up
    # disabled on some VMs for reasons we couldn't track down. This
    # condition causes tests which rely on resolving UNC style paths
    # (like \\localhost) to fail with unhelpful error messages.
    # Put a check for this upfront to aid debug should this strike again.
    service = Puppet::Type.type(:service).new(:name => 'lmhosts')
    expect(service.provider.status).to eq(:running), 'lmhosts service is not running'
  end

  let (:sids) { @sids }
  let (:winsec) { WindowsSecurityTester.new }
  let (:klass) { Puppet::Util::Windows::File }

  def set_group_depending_on_current_user(path)
    if sids[:current_user] == sids[:system]
      # if the current user is SYSTEM, by setting the group to
      # guest, SYSTEM is automagically given full control, so instead
      # override that behavior with SYSTEM as group and a specific mode
      winsec.set_group(sids[:system], path)
      mode = winsec.get_mode(path)
      winsec.set_mode(mode & ~WindowsSecurityTester::S_IRWXG, path)
    else
      winsec.set_group(sids[:guest], path)
    end
  end

  def grant_everyone_full_access(path)
    sd = winsec.get_security_descriptor(path)
    everyone = 'S-1-1-0'
    inherit = Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE | Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE
    sd.dacl.allow(everyone, klass::FILE_ALL_ACCESS, inherit)
    winsec.set_security_descriptor(path, sd)
  end

  shared_examples_for "only child owner" do
    it "should allow child owner" do
      winsec.set_owner(sids[:guest], parent)
      winsec.set_group(sids[:current_user], parent)
      winsec.set_mode(0700, parent)

      check_delete(path)
    end

    it "should deny parent owner" do
      winsec.set_owner(sids[:guest], path)
      winsec.set_group(sids[:current_user], path)
      winsec.set_mode(0700, path)

      expect { check_delete(path) }.to raise_error(Errno::EACCES)
    end

    it "should deny group" do
      winsec.set_owner(sids[:guest], path)
      winsec.set_group(sids[:current_user], path)
      winsec.set_mode(0700, path)

      expect { check_delete(path) }.to raise_error(Errno::EACCES)
    end

    it "should deny other" do
      winsec.set_owner(sids[:guest], path)
      winsec.set_group(sids[:current_user], path)
      winsec.set_mode(0700, path)

      expect { check_delete(path) }.to raise_error(Errno::EACCES)
    end
  end

  shared_examples_for "a securable object" do
    describe "on a volume that doesn't support ACLs" do
      [:owner, :group, :mode].each do |p|
        it "should return nil #{p}" do
          winsec.stubs(:supports_acl?).returns false

          expect(winsec.send("get_#{p}", path)).to be_nil
        end
      end
    end

    describe "on a volume that supports ACLs" do
      describe "for a normal user" do
        before :each do
          Puppet.features.stubs(:root?).returns(false)
        end

        after :each do
          winsec.set_mode(WindowsSecurityTester::S_IRWXU, parent)
          winsec.set_mode(WindowsSecurityTester::S_IRWXU, path) if Puppet::FileSystem.exist?(path)
        end

        describe "#supports_acl?" do
          %w[c:/ c:\\ c:/windows/system32 \\\\localhost\\C$ \\\\127.0.0.1\\C$\\foo].each do |path|
            it "should accept #{path}" do
              expect(winsec).to be_supports_acl(path)
            end
          end

          it "should raise an exception if it cannot get volume information" do
            expect {
              winsec.supports_acl?('foobar')
            }.to raise_error(Puppet::Error, /Failed to get volume information/)
          end
        end

        describe "#owner=" do
          it "should allow setting to the current user" do
            winsec.set_owner(sids[:current_user], path)
          end

          it "should raise an exception when setting to a different user" do
            expect { winsec.set_owner(sids[:guest], path) }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(1307) # ERROR_INVALID_OWNER
            end
          end
        end

        describe "#owner" do
          it "it should not be empty" do
            expect(winsec.get_owner(path)).not_to be_empty
          end

          it "should raise an exception if an invalid path is provided" do
            expect { winsec.get_owner("c:\\doesnotexist.txt") }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(2) # ERROR_FILE_NOT_FOUND
            end
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
            expect(winsec.get_group(path)).not_to be_empty
          end

          it "should raise an exception if an invalid path is provided" do
            expect { winsec.get_group("c:\\doesnotexist.txt") }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(2) # ERROR_FILE_NOT_FOUND
            end
          end
        end

        it "should preserve inherited full control for SYSTEM when setting owner and group" do
          # new file has SYSTEM
          system_aces = winsec.get_aces_for_path_by_sid(path, sids[:system])
          expect(system_aces).not_to be_empty

          # when running under SYSTEM account, multiple ACEs come back
          # so we only care that we have at least one of these
          expect(system_aces.any? do |ace|
            ace.mask == klass::FILE_ALL_ACCESS
          end).to be_truthy

          # changing the owner/group will no longer make the SD protected
          winsec.set_group(sids[:power_users], path)
          winsec.set_owner(sids[:administrators], path)

          expect(system_aces.find do |ace|
            ace.mask == klass::FILE_ALL_ACCESS && ace.inherited?
          end).not_to be_nil
        end

        describe "#mode=" do
          (0000..0700).step(0100) do |mode|
            it "should enforce mode #{mode.to_s(8)}" do
              winsec.set_mode(mode, path)

              check_access(mode, path)
            end
          end

          it "should round-trip all 128 modes that do not require deny ACEs" do
            0.upto(1).each do |s|
              0.upto(7).each do |u|
                0.upto(u).each do |g|
                  0.upto(g).each do |o|
                    # if user is superset of group, and group superset of other, then
                    # no deny ace is required, and mode can be converted to win32
                    # access mask, and back to mode without loss of information
                    # (provided the owner and group are not the same)
                    next if ((u & g) != g) or ((g & o) != o)

                    mode = (s << 9 | u << 6 | g << 3 | o << 0)
                    winsec.set_mode(mode, path)
                    expect(winsec.get_mode(path).to_s(8)).to eq(mode.to_s(8))
                  end
                end
              end
            end
          end

          it "should preserve full control for SYSTEM when setting mode" do
            # new file has SYSTEM
            system_aces = winsec.get_aces_for_path_by_sid(path, sids[:system])
            expect(system_aces).not_to be_empty

            # when running under SYSTEM account, multiple ACEs come back
            # so we only care that we have at least one of these
            expect(system_aces.any? do |ace|
              ace.mask == klass::FILE_ALL_ACCESS
            end).to be_truthy

            # changing the mode will make the SD protected
            winsec.set_group(sids[:none], path)
            winsec.set_mode(0600, path)

            # and should have a non-inherited SYSTEM ACE(s)
            system_aces = winsec.get_aces_for_path_by_sid(path, sids[:system])
            system_aces.each do |ace|
              expect(ace.mask).to eq(klass::FILE_ALL_ACCESS)
              expect(ace).not_to be_inherited
            end

            if Puppet::FileSystem.directory?(path)
              system_aces.each do |ace|
                expect(ace).to be_object_inherit
                expect(ace).to be_container_inherit
              end

              # it's critically important that this file be default created
              # and that this file not have it's owner / group / mode set by winsec
              nested_file = File.join(path, 'nested_file')
              File.new(nested_file, 'w').close

              system_aces = winsec.get_aces_for_path_by_sid(nested_file, sids[:system])
              # even when SYSTEM is the owner (in CI), there should be an inherited SYSTEM
              expect(system_aces.any? do |ace|
                ace.mask == klass::FILE_ALL_ACCESS && ace.inherited?
              end).to be_truthy
            end
          end

          describe "for modes that require deny aces" do
            it "should map everyone to group and owner" do
              winsec.set_mode(0426, path)
              expect(winsec.get_mode(path).to_s(8)).to eq("666")
            end

            it "should combine user and group modes when owner and group sids are equal" do
              winsec.set_group(winsec.get_owner(path), path)

              winsec.set_mode(0410, path)
              expect(winsec.get_mode(path).to_s(8)).to eq("550")
            end
          end

          describe "for read-only objects" do
            before :each do
              winsec.set_group(sids[:none], path)
              winsec.set_mode(0600, path)
              Puppet::Util::Windows::File.add_attributes(path, klass::FILE_ATTRIBUTE_READONLY)
              expect(Puppet::Util::Windows::File.get_attributes(path) & klass::FILE_ATTRIBUTE_READONLY).to be_nonzero
            end

            it "should make them writable if any sid has write permission" do
              winsec.set_mode(WindowsSecurityTester::S_IWUSR, path)
              expect(Puppet::Util::Windows::File.get_attributes(path) & klass::FILE_ATTRIBUTE_READONLY).to eq(0)
            end

            it "should leave them read-only if no sid has write permission and should allow full access for SYSTEM" do
              winsec.set_mode(WindowsSecurityTester::S_IRUSR | WindowsSecurityTester::S_IXGRP, path)
              expect(Puppet::Util::Windows::File.get_attributes(path) & klass::FILE_ATTRIBUTE_READONLY).to be_nonzero

              system_aces = winsec.get_aces_for_path_by_sid(path, sids[:system])

              # when running under SYSTEM account, and set_group / set_owner hasn't been called
              # SYSTEM full access will be restored
              expect(system_aces.any? do |ace|
                ace.mask == klass::FILE_ALL_ACCESS
              end).to be_truthy
            end
          end

          it "should raise an exception if an invalid path is provided" do
            expect { winsec.set_mode(sids[:guest], "c:\\doesnotexist.txt") }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(2) # ERROR_FILE_NOT_FOUND
            end
          end
        end

        describe "#mode" do
          it "should report when extra aces are encounted" do
            sd = winsec.get_security_descriptor(path)
            (544..547).each do |rid|
              sd.dacl.allow("S-1-5-32-#{rid}", klass::STANDARD_RIGHTS_ALL)
            end
            winsec.set_security_descriptor(path, sd)

            mode = winsec.get_mode(path)
            expect(mode & WindowsSecurityTester::S_IEXTRA).to eq(WindowsSecurityTester::S_IEXTRA)
          end

          it "should return deny aces" do
            sd = winsec.get_security_descriptor(path)
            sd.dacl.deny(sids[:guest], klass::FILE_GENERIC_WRITE)
            winsec.set_security_descriptor(path, sd)

            guest_aces = winsec.get_aces_for_path_by_sid(path, sids[:guest])
            expect(guest_aces.find do |ace|
              ace.type == Puppet::Util::Windows::AccessControlEntry::ACCESS_DENIED_ACE_TYPE
            end).not_to be_nil
          end

          it "should skip inherit-only ace" do
            sd = winsec.get_security_descriptor(path)
            dacl = Puppet::Util::Windows::AccessControlList.new
            dacl.allow(
              sids[:current_user], klass::STANDARD_RIGHTS_ALL | klass::SPECIFIC_RIGHTS_ALL
            )
            dacl.allow(
              sids[:everyone],
              klass::FILE_GENERIC_READ,
              Puppet::Util::Windows::AccessControlEntry::INHERIT_ONLY_ACE | Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE
            )
            winsec.set_security_descriptor(path, sd)

            expect(winsec.get_mode(path) & WindowsSecurityTester::S_IRWXO).to eq(0)
          end

          it "should raise an exception if an invalid path is provided" do
            expect { winsec.get_mode("c:\\doesnotexist.txt") }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(2) # ERROR_FILE_NOT_FOUND
            end
          end
        end

        describe "inherited access control entries" do
          it "should be absent when the access control list is protected, and should not remove SYSTEM" do
            winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)

            mode = winsec.get_mode(path)
            [ WindowsSecurityTester::S_IEXTRA,
              WindowsSecurityTester::S_ISYSTEM_MISSING ].each do |flag|
              expect(mode & flag).not_to eq(flag)
            end
          end

          it "should be present when the access control list is unprotected" do
            # add a bunch of aces to the parent with permission to add children
            allow = klass::STANDARD_RIGHTS_ALL | klass::SPECIFIC_RIGHTS_ALL
            inherit = Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE | Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE

            sd = winsec.get_security_descriptor(parent)
            sd.dacl.allow(
              "S-1-1-0", #everyone
              allow,
              inherit
            )
            (544..547).each do |rid|
              sd.dacl.allow(
                "S-1-5-32-#{rid}",
                klass::STANDARD_RIGHTS_ALL,
                inherit
              )
            end
            winsec.set_security_descriptor(parent, sd)

            # unprotect child, it should inherit from parent
            winsec.set_mode(WindowsSecurityTester::S_IRWXU, path, false)
            expect(winsec.get_mode(path) & WindowsSecurityTester::S_IEXTRA).to eq(WindowsSecurityTester::S_IEXTRA)
          end
        end
      end

      describe "for an administrator", :if => (Puppet.features.root? && Puppet.features.microsoft_windows?) do
        before :each do
          is_dir = Puppet::FileSystem.directory?(path)
          winsec.set_mode(WindowsSecurityTester::S_IRWXU | WindowsSecurityTester::S_IRWXG, path)
          set_group_depending_on_current_user(path)
          winsec.set_owner(sids[:guest], path)
          expected_error = RUBY_VERSION =~ /^2\./ && is_dir ? Errno::EISDIR : Errno::EACCES
          expect { File.open(path, 'r') }.to raise_error(expected_error)
        end

        after :each do
          if Puppet::FileSystem.exist?(path)
            winsec.set_owner(sids[:current_user], path)
            winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)
          end
        end

        describe "#owner=" do
          it "should accept the guest sid" do
            winsec.set_owner(sids[:guest], path)
            expect(winsec.get_owner(path)).to eq(sids[:guest])
          end

          it "should accept a user sid" do
            winsec.set_owner(sids[:current_user], path)
            expect(winsec.get_owner(path)).to eq(sids[:current_user])
          end

          it "should accept a group sid" do
            winsec.set_owner(sids[:power_users], path)
            expect(winsec.get_owner(path)).to eq(sids[:power_users])
          end

          it "should raise an exception if an invalid sid is provided" do
            expect { winsec.set_owner("foobar", path) }.to raise_error(Puppet::Error, /Failed to convert string SID/)
          end

          it "should raise an exception if an invalid path is provided" do
            expect { winsec.set_owner(sids[:guest], "c:\\doesnotexist.txt") }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(2) # ERROR_FILE_NOT_FOUND
            end
          end
        end

        describe "#group=" do
          it "should accept the test group" do
            winsec.set_group(sids[:guest], path)
            expect(winsec.get_group(path)).to eq(sids[:guest])
          end

          it "should accept a group sid" do
            winsec.set_group(sids[:power_users], path)
            expect(winsec.get_group(path)).to eq(sids[:power_users])
          end

          it "should accept a user sid" do
            winsec.set_group(sids[:current_user], path)
            expect(winsec.get_group(path)).to eq(sids[:current_user])
          end

          it "should combine owner and group rights when they are the same sid" do
            winsec.set_owner(sids[:power_users], path)
            winsec.set_group(sids[:power_users], path)
            winsec.set_mode(0610, path)

            expect(winsec.get_owner(path)).to eq(sids[:power_users])
            expect(winsec.get_group(path)).to eq(sids[:power_users])
            # note group execute permission added to user ace, and then group rwx value
            # reflected to match

            # Exclude missing system ace, since that's not relevant
            expect((winsec.get_mode(path) & 0777).to_s(8)).to eq("770")
          end

          it "should raise an exception if an invalid sid is provided" do
            expect { winsec.set_group("foobar", path) }.to raise_error(Puppet::Error, /Failed to convert string SID/)
          end

          it "should raise an exception if an invalid path is provided" do
            expect { winsec.set_group(sids[:guest], "c:\\doesnotexist.txt") }.to raise_error do |error|
              expect(error).to be_a(Puppet::Util::Windows::Error)
              expect(error.code).to eq(2) # ERROR_FILE_NOT_FOUND
            end
          end
        end

        describe "when the sid is NULL" do
          it "should retrieve an empty owner sid"
          it "should retrieve an empty group sid"
        end

        describe "when the sid refers to a deleted trustee" do
          it "should retrieve the user sid" do
            sid = nil
            user = Puppet::Util::Windows::ADSI::User.create("puppet#{rand(10000)}")
            user.password = 'PUPPET_RULeZ_123!'
            user.commit
            begin
              sid = Puppet::Util::Windows::ADSI::User.new(user.name).sid.sid
              winsec.set_owner(sid, path)
              winsec.set_mode(WindowsSecurityTester::S_IRWXU, path)
            ensure
              Puppet::Util::Windows::ADSI::User.delete(user.name)
            end

            expect(winsec.get_owner(path)).to eq(sid)
            expect(winsec.get_mode(path)).to eq(WindowsSecurityTester::S_IRWXU)
          end

          it "should retrieve the group sid" do
            sid = nil
            group = Puppet::Util::Windows::ADSI::Group.create("puppet#{rand(10000)}")
            group.commit
            begin
              sid = Puppet::Util::Windows::ADSI::Group.new(group.name).sid.sid
              winsec.set_group(sid, path)
              winsec.set_mode(WindowsSecurityTester::S_IRWXG, path)
            ensure
              Puppet::Util::Windows::ADSI::Group.delete(group.name)
            end
            expect(winsec.get_group(path)).to eq(sid)
            expect(winsec.get_mode(path)).to eq(WindowsSecurityTester::S_IRWXG)
          end
        end

        describe "#mode" do
          it "should deny all access when the DACL is empty, including SYSTEM" do
            sd = winsec.get_security_descriptor(path)
            # don't allow inherited aces to affect the test
            protect = true
            new_sd = Puppet::Util::Windows::SecurityDescriptor.new(sd.owner, sd.group, [], protect)
            winsec.set_security_descriptor(path, new_sd)

            expect(winsec.get_mode(path)).to eq(WindowsSecurityTester::S_ISYSTEM_MISSING)
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

        describe "when the parent directory" do
          before :each do
            winsec.set_owner(sids[:current_user], parent)
            winsec.set_owner(sids[:current_user], path)
            winsec.set_mode(0777, path, false)
          end

          describe "is writable and executable" do
            describe "and sticky bit is set" do
              it "should allow child owner" do
                winsec.set_owner(sids[:guest], parent)
                winsec.set_group(sids[:current_user], parent)
                winsec.set_mode(01700, parent)

                check_delete(path)
              end

              it "should allow parent owner" do
                winsec.set_owner(sids[:current_user], parent)
                winsec.set_group(sids[:guest], parent)
                winsec.set_mode(01700, parent)

                winsec.set_owner(sids[:current_user], path)
                winsec.set_group(sids[:guest], path)
                winsec.set_mode(0700, path)

                check_delete(path)
              end

              it "should deny group" do
                winsec.set_owner(sids[:guest], parent)
                winsec.set_group(sids[:current_user], parent)
                winsec.set_mode(01770, parent)

                winsec.set_owner(sids[:guest], path)
                winsec.set_group(sids[:current_user], path)
                winsec.set_mode(0700, path)

                expect { check_delete(path) }.to raise_error(Errno::EACCES)
              end

              it "should deny other" do
                winsec.set_owner(sids[:guest], parent)
                winsec.set_group(sids[:current_user], parent)
                winsec.set_mode(01777, parent)

                winsec.set_owner(sids[:guest], path)
                winsec.set_group(sids[:current_user], path)
                winsec.set_mode(0700, path)

                expect { check_delete(path) }.to raise_error(Errno::EACCES)
              end
            end

            describe "and sticky bit is not set" do
              it "should allow child owner" do
                winsec.set_owner(sids[:guest], parent)
                winsec.set_group(sids[:current_user], parent)
                winsec.set_mode(0700, parent)

                check_delete(path)
              end

              it "should allow parent owner" do
                winsec.set_owner(sids[:current_user], parent)
                winsec.set_group(sids[:guest], parent)
                winsec.set_mode(0700, parent)

                winsec.set_owner(sids[:current_user], path)
                winsec.set_group(sids[:guest], path)
                winsec.set_mode(0700, path)

                check_delete(path)
              end

              it "should allow group" do
                winsec.set_owner(sids[:guest], parent)
                winsec.set_group(sids[:current_user], parent)
                winsec.set_mode(0770, parent)

                winsec.set_owner(sids[:guest], path)
                winsec.set_group(sids[:current_user], path)
                winsec.set_mode(0700, path)

                check_delete(path)
              end

              it "should allow other" do
                winsec.set_owner(sids[:guest], parent)
                winsec.set_group(sids[:current_user], parent)
                winsec.set_mode(0777, parent)

                winsec.set_owner(sids[:guest], path)
                winsec.set_group(sids[:current_user], path)
                winsec.set_mode(0700, path)

                check_delete(path)
              end
            end
          end

          describe "is not writable" do
            before :each do
              winsec.set_group(sids[:current_user], parent)
              winsec.set_mode(0555, parent)
            end

            it_behaves_like "only child owner"
          end

          describe "is not executable" do
            before :each do
              winsec.set_group(sids[:current_user], parent)
              winsec.set_mode(0666, parent)
            end

            it_behaves_like "only child owner"
          end
        end
      end
    end
  end

  describe "file" do
    let (:parent) do
      tmpdir('win_sec_test_file')
    end

    let (:path) do
      path = File.join(parent, 'childfile')
      File.new(path, 'w').close
      path
    end

    after :each do
      # allow temp files to be cleaned up
      grant_everyone_full_access(parent)
    end

    it_behaves_like "a securable object" do
      def check_access(mode, path)
        if (mode & WindowsSecurityTester::S_IRUSR).nonzero?
          check_read(path)
        else
          expect { check_read(path) }.to raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IWUSR).nonzero?
          check_write(path)
        else
          expect { check_write(path) }.to raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IXUSR).nonzero?
          expect { check_execute(path) }.to raise_error(Errno::ENOEXEC)
        else
          expect { check_execute(path) }.to raise_error(Errno::EACCES)
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

      def check_delete(path)
        File.delete(path)
      end
    end

    describe "locked files" do
      let (:explorer) { File.join(Dir::WINDOWS, "explorer.exe") }

      it "should get the owner" do
        expect(winsec.get_owner(explorer)).to match(/^S-1-5-/)
      end

      it "should get the group" do
        expect(winsec.get_group(explorer)).to match(/^S-1-5-/)
      end

      it "should get the mode" do
        expect(winsec.get_mode(explorer)).to eq(WindowsSecurityTester::S_IRWXU | WindowsSecurityTester::S_IRWXG | WindowsSecurityTester::S_IEXTRA)
      end
    end
  end

  describe "directory" do
    let (:parent) do
      tmpdir('win_sec_test_dir')
    end

    let (:path) do
      path = File.join(parent, 'childdir')
      Dir.mkdir(path)
      path
    end

    after :each do
      # allow temp files to be cleaned up
      grant_everyone_full_access(parent)
    end

    it_behaves_like "a securable object" do
      def check_access(mode, path)
        if (mode & WindowsSecurityTester::S_IRUSR).nonzero?
          check_read(path)
        else
          expect { check_read(path) }.to raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IWUSR).nonzero?
          check_write(path)
        else
          expect { check_write(path) }.to raise_error(Errno::EACCES)
        end

        if (mode & WindowsSecurityTester::S_IXUSR).nonzero?
          check_execute(path)
        else
          expect { check_execute(path) }.to raise_error(Errno::EACCES)
        end
      end

      def check_read(path)
        Dir.entries(path)
      end

      def check_write(path)
        Dir.mkdir(File.join(path, "subdir"))
      end

      def check_execute(path)
        Dir.chdir(path) {}
      end

      def check_delete(path)
        Dir.rmdir(path)
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
          mode = winsec.get_mode(p)
          expect((mode & 07777).to_s(8)).to eq(mode640.to_s(8))
        end
      end
    end
  end

  context "security descriptor" do
    let(:path) { tmpfile('sec_descriptor') }
    let(:read_execute) { 0x201FF }
    let(:synchronize)  { 0x100000 }

    before :each do
      FileUtils.touch(path)
    end

    it "preserves aces for other users" do
      dacl = Puppet::Util::Windows::AccessControlList.new
      sids_in_dacl = [sids[:current_user], sids[:users]]
      sids_in_dacl.each do |sid|
        dacl.allow(sid, read_execute)
      end
      sd = Puppet::Util::Windows::SecurityDescriptor.new(sids[:guest], sids[:guest], dacl, true)
      winsec.set_security_descriptor(path, sd)

      aces = winsec.get_security_descriptor(path).dacl.to_a
      expect(aces.map(&:sid)).to eq(sids_in_dacl)
      expect(aces.map(&:mask).all? { |mask| mask == read_execute }).to be_truthy
    end

    it "changes the sid for all aces that were assigned to the old owner" do
      sd = winsec.get_security_descriptor(path)
      expect(sd.owner).not_to eq(sids[:guest])

      sd.dacl.allow(sd.owner, read_execute)
      sd.dacl.allow(sd.owner, synchronize)

      sd.owner = sids[:guest]
      winsec.set_security_descriptor(path, sd)

      dacl = winsec.get_security_descriptor(path).dacl
      aces = dacl.find_all { |ace| ace.sid == sids[:guest] }
      # only non-inherited aces will be reassigned to guest, so
      # make sure we find at least the two we added
      expect(aces.size).to be >= 2
    end

    it "preserves INHERIT_ONLY_ACEs" do
      # inherit only aces can only be set on directories
      dir = tmpdir('inheritonlyace')

      inherit_flags = Puppet::Util::Windows::AccessControlEntry::INHERIT_ONLY_ACE |
        Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE |
        Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE

      sd = winsec.get_security_descriptor(dir)
      sd.dacl.allow(sd.owner, klass::FILE_ALL_ACCESS, inherit_flags)
      winsec.set_security_descriptor(dir, sd)

      sd = winsec.get_security_descriptor(dir)

      winsec.set_owner(sids[:guest], dir)

      sd = winsec.get_security_descriptor(dir)
      expect(sd.dacl.find do |ace|
        ace.sid == sids[:guest] && ace.inherit_only?
      end).not_to be_nil
    end

    it "allows deny ACEs with inheritance" do
      # inheritance can only be set on directories
      dir = tmpdir('denyaces')

      inherit_flags = Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE |
          Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE

      sd = winsec.get_security_descriptor(dir)
      sd.dacl.deny(sids[:guest], klass::FILE_ALL_ACCESS, inherit_flags)
      winsec.set_security_descriptor(dir, sd)

      sd = winsec.get_security_descriptor(dir)
      expect(sd.dacl.find do |ace|
        ace.sid == sids[:guest] && ace.flags != 0
      end).not_to be_nil
    end

    context "when managing mode" do
      it "removes aces for sids that are neither the owner nor group" do
        # add a guest ace, it's never owner or group
        sd = winsec.get_security_descriptor(path)
        sd.dacl.allow(sids[:guest], read_execute)
        winsec.set_security_descriptor(path, sd)

        # setting the mode, it should remove extra aces
        winsec.set_mode(0770, path)

        # make sure it's gone
        dacl = winsec.get_security_descriptor(path).dacl
        aces = dacl.find_all { |ace| ace.sid == sids[:guest] }
        expect(aces).to be_empty
      end
    end
  end
end
