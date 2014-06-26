#! /usr/bin/env ruby

require 'spec_helper'
require 'facter'

describe "Puppet::Util::Windows::Process", :if => Puppet.features.microsoft_windows?  do
  describe "as an admin" do
    it "should have the SeCreateSymbolicLinkPrivilege necessary to create symlinks on Vista / 2008+",
      :if => Facter.value(:kernelmajversion).to_f >= 6.0 && Puppet.features.microsoft_windows? do
      # this is a bit of a lame duck test since it requires running user to be admin
      # a better integration test would create a new user with the privilege and verify
      Puppet::Util::Windows::User.should be_admin
      Puppet::Util::Windows::Process.process_privilege_symlink?.should be_true
    end

    it "should not have the SeCreateSymbolicLinkPrivilege necessary to create symlinks on 2003 and earlier",
      :if => Facter.value(:kernelmajversion).to_f < 6.0 && Puppet.features.microsoft_windows? do
      Puppet::Util::Windows::User.should be_admin
      Puppet::Util::Windows::Process.process_privilege_symlink?.should be_false
    end

    it "should be able to lookup a standard Windows process privilege" do
      Puppet::Util::Windows::Process.lookup_privilege_value('SeShutdownPrivilege') do |luid|
        luid.should_not be_nil
        luid.should be_instance_of(Puppet::Util::Windows::Process::LUID)
      end
    end

    it "should raise an error for an unknown privilege name" do
      fail_msg = /LookupPrivilegeValue\(, foo, .*\):  A specified privilege does not exist/
      expect { Puppet::Util::Windows::Process.lookup_privilege_value('foo') }.to raise_error(Puppet::Util::Windows::Error, fail_msg)
    end
  end
end
