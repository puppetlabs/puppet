#! /usr/bin/env ruby

require 'spec_helper'
require 'facter'

describe "Puppet::Util::Windows::Process", :if => Puppet.features.microsoft_windows?  do
  describe "as an admin" do
    it "should have the SeCreateSymbolicLinkPrivilege necessary to create symlinks on Vista / 2008+",
      :if => Facter.value(:kernelmajversion).to_f >= 6.0 && Puppet.features.microsoft_windows? do
      # this is a bit of a lame duck test since it requires running user to be admin
      # a better integration test would create a new user with the privilege and verify
      expect(Puppet::Util::Windows::User).to be_admin
      expect(Puppet::Util::Windows::Process.process_privilege_symlink?).to be_truthy
    end

    it "should not have the SeCreateSymbolicLinkPrivilege necessary to create symlinks on 2003 and earlier",
      :if => Facter.value(:kernelmajversion).to_f < 6.0 && Puppet.features.microsoft_windows? do
      expect(Puppet::Util::Windows::User).to be_admin
      expect(Puppet::Util::Windows::Process.process_privilege_symlink?).to be_falsey
    end

    it "should be able to lookup a standard Windows process privilege" do
      Puppet::Util::Windows::Process.lookup_privilege_value('SeShutdownPrivilege') do |luid|
        expect(luid).not_to be_nil
        expect(luid).to be_instance_of(Puppet::Util::Windows::Process::LUID)
      end
    end

    it "should raise an error for an unknown privilege name" do
      fail_msg = /LookupPrivilegeValue\(, foo, .*\):  A specified privilege does not exist/
      expect { Puppet::Util::Windows::Process.lookup_privilege_value('foo') }.to raise_error(Puppet::Util::Windows::Error, fail_msg)
    end
  end

  describe "when setting environment variables" do
    it "can properly handle env var values with = in them" do
      begin
        name = SecureRandom.uuid
        value = 'foo=bar'

        Puppet::Util::Windows::Process.set_environment_variable(name, value)

        env = Puppet::Util::Windows::Process.get_environment_strings

        expect(env[name]).to eq(value)
      ensure
        Puppet::Util::Windows::Process.set_environment_variable(name, nil)
      end
    end

    it "can properly handle empty env var values" do
      begin
        name = SecureRandom.uuid

        Puppet::Util::Windows::Process.set_environment_variable(name, '')

        env = Puppet::Util::Windows::Process.get_environment_strings

        expect(env[name]).to eq('')
      ensure
        Puppet::Util::Windows::Process.set_environment_variable(name, nil)
      end
    end
  end
end
