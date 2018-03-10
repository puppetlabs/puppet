#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe Puppet::Util::Windows::SID::Principal, :if => Puppet.features.microsoft_windows? do

  let (:current_user_sid) { Puppet::Util::Windows::ADSI::User.current_user_sid }
  let (:system_bytes) { [1, 1, 0, 0, 0, 0, 0, 5, 18, 0, 0, 0] }
  let (:null_sid_bytes) { [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] }
  let (:administrator_bytes) { [1, 2, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0, 32, 2, 0, 0] }
  let (:computer_sid) { Puppet::Util::Windows::SID.name_to_principal(Puppet::Util::Windows::ADSI.computer_name) }
  # BUILTIN is localized on German Windows, but not French
  # looking this up like this dilutes the values of the tests as we're comparing two mechanisms
  # for returning the same values, rather than to a known good
  let (:builtin_localized) { Puppet::Util::Windows::SID.sid_to_name('S-1-5-32') }

  describe ".lookup_account_name" do
    it "should create an instance from a well-known account name" do
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_name('NULL SID')
      expect(principal.account).to eq('NULL SID')
      expect(principal.sid_bytes).to eq(null_sid_bytes)
      expect(principal.sid).to eq('S-1-0-0')
      expect(principal.domain).to eq('')
      expect(principal.domain_account).to eq('NULL SID')
      expect(principal.account_type).to eq(:SidTypeWellKnownGroup)
      expect(principal.to_s).to eq('NULL SID')
    end

    it "should create an instance from a well-known account prefixed with NT AUTHORITY" do
      # a special case that can be used to lookup an account on a localized Windows
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_name('NT AUTHORITY\\SYSTEM')
      expect(principal.sid_bytes).to eq(system_bytes)
      expect(principal.sid).to eq('S-1-5-18')

      # guard these 3 checks on a US Windows with 1033 - primary language id of 9
      primary_language_id = 9
      # even though lookup in English, returned values may be localized
      # French Windows returns AUTORITE NT\\Syst\u00E8me, German Windows returns NT-AUTORIT\u00C4T\\SYSTEM
      if (Puppet::Util::Windows::Process.get_system_default_ui_language & primary_language_id == primary_language_id)
        expect(principal.account).to eq('SYSTEM')
        expect(principal.domain).to eq('NT AUTHORITY')
        expect(principal.domain_account).to eq('NT AUTHORITY\\SYSTEM')
        expect(principal.to_s).to eq('NT AUTHORITY\\SYSTEM')
      end

      # Windows API LookupAccountSid behaves differently if current user is SYSTEM
      if current_user_sid.sid_bytes != system_bytes
        account_type = :SidTypeWellKnownGroup
      else
        account_type = :SidTypeUser
      end

      expect(principal.account_type).to eq(account_type)
    end

    it "should create an instance from a local account prefixed with hostname" do
      running_as_system = (current_user_sid.sid_bytes == system_bytes)
      username = running_as_system ?
        # need to return localized name of Administrator account
        Puppet::Util::Windows::SID.sid_to_name(computer_sid.sid + '-500').split('\\').last :
        current_user_sid.account

      user_exists = Puppet::Util::Windows::ADSI::User.exists?(".\\#{username}")

      # when running as SYSTEM (in Jenkins CI), then Administrator should be used
      # otherwise running in AppVeyor there is no Administrator and a the current local user can be used
      skip if (running_as_system && !user_exists)

      hostname = Puppet::Util::Windows::ADSI.computer_name

      principal = Puppet::Util::Windows::SID::Principal.lookup_account_name("#{hostname}\\#{username}")
      expect(principal.account).to match(/^#{Regexp.quote(username)}$/i)
      # skip SID and bytes in this case since the most interesting thing here is domain_account
      expect(principal.domain).to match(/^#{Regexp.quote(hostname)}$/i)
      expect(principal.domain_account).to match(/^#{Regexp.quote(hostname)}\\#{Regexp.quote(username)}$/i)
      expect(principal.account_type).to eq(:SidTypeUser)
    end

    it "should create an instance from a well-known BUILTIN alias" do
      # by looking up the localized name of the account, the test value is diluted
      # this localizes Administrators AND BUILTIN
      qualified_name = Puppet::Util::Windows::SID.sid_to_name('S-1-5-32-544')
      domain, name = qualified_name.split('\\')
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_name(name)

      expect(principal.account).to eq(name)
      expect(principal.sid_bytes).to eq(administrator_bytes)
      expect(principal.sid).to eq('S-1-5-32-544')
      expect(principal.domain).to eq(domain)
      expect(principal.domain_account).to eq(qualified_name)
      expect(principal.account_type).to eq(:SidTypeAlias)
      expect(principal.to_s).to eq(qualified_name)
    end

    it "should raise an error when trying to lookup an account that doesn't exist" do
      principal = Puppet::Util::Windows::SID::Principal
      expect {
        principal.lookup_account_name('ConanTheBarbarian')
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(1332) # ERROR_NONE_MAPPED
      end
    end

    it "should return a BUILTIN domain principal for empty account names" do
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_name('')
      expect(principal.account_type).to eq(:SidTypeDomain)
      expect(principal.sid).to eq('S-1-5-32')
      expect(principal.account).to eq(builtin_localized)
      expect(principal.domain).to eq(builtin_localized)
      expect(principal.domain_account).to eq(builtin_localized)
      expect(principal.to_s).to eq(builtin_localized)
    end

    it "should return a BUILTIN domain principal for BUILTIN account names" do
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_name(builtin_localized)
      expect(principal.account_type).to eq(:SidTypeDomain)
      expect(principal.sid).to eq('S-1-5-32')
      expect(principal.account).to eq(builtin_localized)
      expect(principal.domain).to eq(builtin_localized)
      expect(principal.domain_account).to eq(builtin_localized)
      expect(principal.to_s).to eq(builtin_localized)
    end

  end

  describe ".lookup_account_sid" do
    it "should create an instance from a user SID" do
      # take the computer account bytes and append the equivalent of -501 for Guest
      bytes = (computer_sid.sid_bytes + [245, 1, 0, 0])
      # computer SID bytes start with [1, 4, ...] but need to be [1, 5, ...]
      bytes[1] = 5
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_sid(bytes)
      # use the returned SID to lookup localized Guest account name in Windows
      guest_name = Puppet::Util::Windows::SID.sid_to_name(principal.sid)

      expect(principal.sid_bytes).to eq(bytes)
      expect(principal.sid).to eq(computer_sid.sid + '-501')
      expect(principal.account).to eq(guest_name.split('\\')[1])
      expect(principal.domain).to eq(computer_sid.domain)
      expect(principal.domain_account).to eq(guest_name)
      expect(principal.account_type).to eq(:SidTypeUser)
      expect(principal.to_s).to eq(guest_name)
    end

    it "should create an instance from a well-known group SID" do
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_sid(null_sid_bytes)
      expect(principal.sid_bytes).to eq(null_sid_bytes)
      expect(principal.sid).to eq('S-1-0-0')
      expect(principal.account).to eq('NULL SID')
      expect(principal.domain).to eq('')
      expect(principal.domain_account).to eq('NULL SID')
      expect(principal.account_type).to eq(:SidTypeWellKnownGroup)
      expect(principal.to_s).to eq('NULL SID')
    end

    it "should create an instance from a well-known BUILTIN Alias SID" do
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_sid(administrator_bytes)
      # by looking up the localized name of the account, the test value is diluted
      # this localizes Administrators AND BUILTIN
      qualified_name = Puppet::Util::Windows::SID.sid_to_name('S-1-5-32-544')
      domain, name = qualified_name.split('\\')

      expect(principal.account).to eq(name)
      expect(principal.sid_bytes).to eq(administrator_bytes)
      expect(principal.sid).to eq('S-1-5-32-544')
      expect(principal.domain).to eq(domain)
      expect(principal.domain_account).to eq(qualified_name)
      expect(principal.account_type).to eq(:SidTypeAlias)
      expect(principal.to_s).to eq(qualified_name)
    end

    it "should raise an error when trying to lookup nil" do
      principal = Puppet::Util::Windows::SID::Principal
      expect {
        principal.lookup_account_sid(nil)
      }.to raise_error(Puppet::Util::Windows::Error, /must not be nil/)
    end

    it "should raise an error when trying to lookup non-byte array" do
      principal = Puppet::Util::Windows::SID::Principal
      expect {
        principal.lookup_account_sid('ConanTheBarbarian')
      }.to raise_error(Puppet::Util::Windows::Error, /array/)
    end

    it "should raise an error when trying to lookup an empty array" do
      principal = Puppet::Util::Windows::SID::Principal
      expect {
        principal.lookup_account_sid([])
      }.to raise_error(Puppet::Util::Windows::Error, /at least 1 byte long/)
    end

    # https://technet.microsoft.com/en-us/library/cc962011.aspx
    # "... The structure used in all SIDs created by Windows NT and Windows 2000 is revision level 1. ..."
    # Therefore a value of zero for the revision, is not a valid SID
    it "should raise an error when trying to lookup completely invalid SID bytes" do
      principal = Puppet::Util::Windows::SID::Principal
      expect {
        principal.lookup_account_sid([0])
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(87) # ERROR_INVALID_PARAMETER
      end
    end

    it "should raise an error when trying to lookup a valid SID that doesn't have a matching account" do
      principal = Puppet::Util::Windows::SID::Principal
      expect {
        # S-1-1-1 which is not a valid account
        principal.lookup_account_sid([1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0])
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(1332) # ERROR_NONE_MAPPED
      end
    end

    it "should return a domain principal for BUILTIN SID S-1-5-32" do
      principal = Puppet::Util::Windows::SID::Principal.lookup_account_sid([1, 1, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0])
      expect(principal.account_type).to eq(:SidTypeDomain)
      expect(principal.sid).to eq('S-1-5-32')
      expect(principal.account).to eq(builtin_localized)
      expect(principal.domain).to eq(builtin_localized)
      expect(principal.domain_account).to eq(builtin_localized)
      expect(principal.to_s).to eq(builtin_localized)
    end
  end

  describe "it should create matching Principal objects" do
    let(:builtin_sid) { [1, 1, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0] }
    let(:sid_principal) { Puppet::Util::Windows::SID::Principal.lookup_account_sid(builtin_sid) }

    ['.', ''].each do |name|
      it "when comparing the one looked up via SID S-1-5-32 to one looked up via non-canonical name #{name} for the BUILTIN domain" do
        name_principal = Puppet::Util::Windows::SID::Principal.lookup_account_name(name)

        # compares canonical sid
        expect(sid_principal).to eq(name_principal)

        # compare all properties that have public accessors
        sid_principal.public_methods(false).reject { |m| m == :== }.each do |method|
          expect(sid_principal.send(method)).to eq(name_principal.send(method))
        end
      end
    end

    it "when comparing the one looked up via SID S-1-5-32 to one looked up via non-canonical localized name for the BUILTIN domain" do
      name_principal = Puppet::Util::Windows::SID::Principal.lookup_account_name(builtin_localized)

      # compares canonical sid
      expect(sid_principal).to eq(name_principal)

      # compare all properties that have public accessors
      sid_principal.public_methods(false).reject { |m| m == :== }.each do |method|
        expect(sid_principal.send(method)).to eq(name_principal.send(method))
      end
    end
  end
end
