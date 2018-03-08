#!/usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Util::Windows::SID", :if => Puppet.features.microsoft_windows? do
  if Puppet.features.microsoft_windows?
    require 'puppet/util/windows'
  end

  let(:subject)      { Puppet::Util::Windows::SID }
  let(:sid)          { Puppet::Util::Windows::SID::LocalSystem }
  let(:invalid_sid)  { 'bogus' }
  let(:unknown_sid)  { 'S-0-0-0' }
  let(:null_sid)     { 'S-1-0-0' }
  let(:unknown_name) { 'chewbacca' }

  context "#octet_string_to_principal" do
    it "should properly convert an array of bytes for a well-known non-localized SID" do
      bytes = [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      converted = subject.octet_string_to_principal(bytes)

      expect(converted).to be_an_instance_of Puppet::Util::Windows::SID::Principal
      expect(converted.sid_bytes).to eq(bytes)
      expect(converted.sid).to eq(null_sid)

      # carefully select a SID here that is not localized on international Windows
      expect(converted.account).to eq('NULL SID')
    end

    it "should raise an error for non-array input" do
      expect {
        subject.octet_string_to_principal(invalid_sid)
      }.to raise_error(Puppet::Error, /Octet string must be an array of bytes/)
    end

    it "should raise an error for an empty byte array" do
      expect {
        subject.octet_string_to_principal([])
      }.to raise_error(Puppet::Error, /Octet string must be an array of bytes/)
    end

    it "should raise an error for a valid byte array with no mapping to a user" do
      expect {
        # S-1-1-1 which is not a valid account
        valid_octet_invalid_user =[1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
        subject.octet_string_to_principal(valid_octet_invalid_user)
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(1332) # ERROR_NONE_MAPPED
      end
    end

    it "should raise an error for a malformed byte array" do
      expect {
        invalid_octet = [2]
        subject.octet_string_to_principal(invalid_octet)
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(87) # ERROR_INVALID_PARAMETER
      end
    end
  end

  context "#name_to_sid" do
    it "should return nil if the account does not exist" do
      expect(subject.name_to_sid(unknown_name)).to be_nil
    end

    it "should accept unqualified account name" do
      # NOTE: lookup by name works in localized environments only for a few instances
      # this works in French Windows, even though the account is really Syst\u00E8me
      expect(subject.name_to_sid('SYSTEM')).to eq(sid)
    end

    it "should return a SID for a passed user or group name" do
      subject.expects(:name_to_principal).with('testers').returns stub(:sid => 'S-1-5-32-547')
      expect(subject.name_to_sid('testers')).to eq('S-1-5-32-547')
    end

    it "should return a SID for a passed fully-qualified user or group name" do
      subject.expects(:name_to_principal).with('MACHINE\testers').returns stub(:sid => 'S-1-5-32-547')
      expect(subject.name_to_sid('MACHINE\testers')).to eq('S-1-5-32-547')
    end

    it "should be case-insensitive" do
      expect(subject.name_to_sid('SYSTEM')).to eq(subject.name_to_sid('system'))
    end

    it "should be leading and trailing whitespace-insensitive" do
      expect(subject.name_to_sid('SYSTEM')).to eq(subject.name_to_sid(' SYSTEM '))
    end

    it "should accept domain qualified account names" do
      # NOTE: lookup by name works in localized environments only for a few instances
      # this works in French Windows, even though the account is really AUTORITE NT\\Syst\u00E8me
      expect(subject.name_to_sid('NT AUTHORITY\SYSTEM')).to eq(sid)
    end

    it "should be the identity function for any sid" do
      expect(subject.name_to_sid(sid)).to eq(sid)
    end

    describe "with non-US languages" do

      UMLAUT = [195, 164].pack('c*').force_encoding(Encoding::UTF_8)
      let(:username) { SecureRandom.uuid.to_s.gsub(/\-/, '')[0..13] + UMLAUT }

      after(:each) {
        Puppet::Util::Windows::ADSI::User.delete(username)
      }

      it "should properly resolve a username with an umlaut" do
        # Ruby seems to use the local codepage when making COM calls
        # if this fails, might want to use Windows API directly instead to ensure bytes
        user = Puppet::Util::Windows::ADSI.create(username, 'user')
        user.SetPassword('PUPPET_RULeZ_123!')
        user.SetInfo()

        # compare the new SID to the name_to_sid result
        sid_bytes = user.objectSID.to_a
        sid_string = ''
        FFI::MemoryPointer.new(:byte, sid_bytes.length) do |sid_byte_ptr|
          sid_byte_ptr.write_array_of_uchar(sid_bytes)
          sid_string = Puppet::Util::Windows::SID.sid_ptr_to_string(sid_byte_ptr)
        end

        expect(subject.name_to_sid(username)).to eq(sid_string)
      end
    end
  end

  context "#name_to_principal" do
    it "should return nil if the account does not exist" do
      expect(subject.name_to_principal(unknown_name)).to be_nil
    end

    it "should return a Puppet::Util::Windows::SID::Principal instance for any valid sid" do
      expect(subject.name_to_principal(sid)).to be_an_instance_of(Puppet::Util::Windows::SID::Principal)
    end

    it "should accept unqualified account name" do
      # NOTE: lookup by name works in localized environments only for a few instances
      # this works in French Windows, even though the account is really Syst\u00E8me
      expect(subject.name_to_principal('SYSTEM').sid).to eq(sid)
    end

    it "should be case-insensitive" do
      # NOTE: lookup by name works in localized environments only for a few instances
      # this works in French Windows, even though the account is really Syst\u00E8me
      expect(subject.name_to_principal('SYSTEM')).to eq(subject.name_to_principal('system'))
    end

    it "should be leading and trailing whitespace-insensitive" do
      # NOTE: lookup by name works in localized environments only for a few instances
      # this works in French Windows, even though the account is really Syst\u00E8me
      expect(subject.name_to_principal('SYSTEM')).to eq(subject.name_to_principal(' SYSTEM '))
    end

    it "should accept domain qualified account names" do
      # NOTE: lookup by name works in localized environments only for a few instances
      # this works in French Windows, even though the account is really AUTORITE NT\\Syst\u00E8me
      expect(subject.name_to_principal('NT AUTHORITY\SYSTEM').sid).to eq(sid)
    end
  end

  context "#ads_to_principal" do
    it "should raise an error for non-WIN32OLE input" do
      expect {
        subject.ads_to_principal(stub('WIN32OLE', { :Name => 'foo' }))
      }.to raise_error(Puppet::Error, /ads_object must be an IAdsUser or IAdsGroup instance/)
    end

    it "should raise an error for an empty byte array in the objectSID property" do
      expect {
        subject.ads_to_principal(stub('WIN32OLE', { :objectSID => [], :Name => '', :ole_respond_to? => true }))
      }.to raise_error(Puppet::Error, /Octet string must be an array of bytes/)
    end

    it "should raise an error for a malformed byte array" do
      expect {
        invalid_octet = [2]
        subject.ads_to_principal(stub('WIN32OLE', { :objectSID => invalid_octet, :Name => '', :ole_respond_to? => true }))
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(87) # ERROR_INVALID_PARAMETER
      end
    end

    it "should raise an error when a valid byte array for SID is unresolvable and its Name does not match" do
      expect {
        # S-1-1-1 is a valid SID that will not resolve
        valid_octet_invalid_user = [1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
        subject.ads_to_principal(stub('WIN32OLE', { :objectSID => valid_octet_invalid_user, :Name => unknown_name, :ole_respond_to? => true }))
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.cause.code).to eq(1332) # ERROR_NONE_MAPPED
      end
    end

    it "should return a Principal object even when the SID is unresolvable, as long as the Name matches" do
      # S-1-1-1 is a valid SID that will not resolve
      valid_octet_invalid_user = [1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
      unresolvable_user = stub('WIN32OLE', { :objectSID => valid_octet_invalid_user, :Name => 'S-1-1-1', :ole_respond_to? => true })
      principal = subject.ads_to_principal(unresolvable_user)

      expect(principal).to be_an_instance_of(Puppet::Util::Windows::SID::Principal)
      expect(principal.account).to eq('S-1-1-1 (unresolvable)')
      expect(principal.domain).to eq(nil)
      expect(principal.domain_account).to eq('S-1-1-1 (unresolvable)')
      expect(principal.sid).to eq('S-1-1-1')
      expect(principal.sid_bytes).to eq(valid_octet_invalid_user)
      expect(principal.account_type).to eq(:SidTypeUnknown)
    end

    it "should return a Puppet::Util::Windows::SID::Principal instance for any valid sid" do
      system_bytes = [1, 1, 0, 0, 0, 0, 0, 5, 18, 0, 0, 0]
      adsuser = stub('WIN32OLE', { :objectSID => system_bytes, :Name => 'SYSTEM', :ole_respond_to? => true })
      expect(subject.ads_to_principal(adsuser)).to be_an_instance_of(Puppet::Util::Windows::SID::Principal)
    end

    it "should properly convert an array of bytes for a well-known non-localized SID, ignoring the Name from the WIN32OLE object" do
      bytes = [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      adsuser = stub('WIN32OLE', { :objectSID => bytes, :Name => unknown_name, :ole_respond_to? => true })
      converted = subject.ads_to_principal(adsuser)

      expect(converted).to be_an_instance_of Puppet::Util::Windows::SID::Principal
      expect(converted.sid_bytes).to eq(bytes)
      expect(converted.sid).to eq(null_sid)

      # carefully select a SID here that is not localized on international Windows
      expect(converted.account).to eq('NULL SID')
      # garbage name supplied does not carry forward as SID is looked up again
      expect(converted.account).to_not eq(adsuser.Name)
    end
  end

  context "#sid_to_name" do
    it "should return nil if given a sid for an account that doesn't exist" do
      expect(subject.sid_to_name(unknown_sid)).to be_nil
    end

    it "should accept a sid" do
      # choose a value that is not localized, for instance
      # S-1-5-18 can be NT AUTHORITY\\SYSTEM or AUTORITE NT\\Syst\u00E8me
      # but NULL SID appears universal
      expect(subject.sid_to_name(null_sid)).to eq('NULL SID')
    end
  end

  context "#sid_ptr_to_string" do
    it "should raise if given an invalid sid" do
      expect {
        subject.sid_ptr_to_string(nil)
      }.to raise_error(Puppet::Error, /Invalid SID/)
    end

    it "should yield a valid sid pointer" do
      string = nil
      subject.string_to_sid_ptr(sid) do |ptr|
        string = subject.sid_ptr_to_string(ptr)
      end
      expect(string).to eq(sid)
    end
  end

  context "#string_to_sid_ptr" do
    it "should yield sid_ptr" do
      ptr = nil
      subject.string_to_sid_ptr(sid) do |p|
        ptr = p
      end
      expect(ptr).not_to be_nil
    end

    it "should raise on an invalid sid" do
      expect {
        subject.string_to_sid_ptr(invalid_sid)
      }.to raise_error(Puppet::Error, /Failed to convert string SID/)
    end
  end

  context "#valid_sid?" do
    it "should return true for a valid SID" do
      expect(subject.valid_sid?(sid)).to be_truthy
    end

    it "should return false for an invalid SID" do
      expect(subject.valid_sid?(invalid_sid)).to be_falsey
    end

    it "should raise if the conversion fails" do
      subject.expects(:string_to_sid_ptr).with(sid).
        raises(Puppet::Util::Windows::Error.new("Failed to convert string SID: #{sid}", Puppet::Util::Windows::Error::ERROR_ACCESS_DENIED))

      expect {
        subject.string_to_sid_ptr(sid) {|ptr| }
      }.to raise_error(Puppet::Util::Windows::Error, /Failed to convert string SID: #{sid}/)
    end
  end
end
