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
  let(:unknown_name) { 'chewbacca' }

  context "#octet_string_to_sid_object" do
    it "should properly convert an array of bytes for a well-known SID" do
      bytes = [1, 1, 0, 0, 0, 0, 0, 5, 18, 0, 0, 0]
      converted = subject.octet_string_to_sid_object(bytes)

      expect(converted).to be_an_instance_of Puppet::Util::Windows::SID::Principal
      expect(converted.sid_bytes).to eq(bytes)
      expect(converted.sid).to eq(sid)
      expect(converted.account).to eq('SYSTEM')
    end

    it "should raise an error for non-array input" do
      expect {
        subject.octet_string_to_sid_object(invalid_sid)
      }.to raise_error(Puppet::Error, /Octet string must be an array of bytes/)
    end

    it "should raise an error for an empty byte array" do
      expect {
        subject.octet_string_to_sid_object([])
      }.to raise_error(Puppet::Error, /Octet string must be an array of bytes/)
    end

    it "should raise an error for a valid byte array with no mapping to a user" do
      expect {
        # S-1-1-1 which is not a valid account
        valid_octet_invalid_user =[1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
        subject.octet_string_to_sid_object(valid_octet_invalid_user)
      }.to raise_error(Puppet::Util::Windows::Error, /Failed to call LookupAccountSidW:  No mapping between account names and security IDs was done./)
    end

    it "should raise an error for a malformed byte array" do
      expect {
        invalid_octet = [2]
        subject.octet_string_to_sid_object(invalid_octet)
      }.to raise_error(Puppet::Util::Windows::Error, /Failed to call LookupAccountSidW:  The parameter is incorrect./)
    end
  end

  context "#name_to_sid" do
    it "should return nil if the account does not exist" do
      expect(subject.name_to_sid(unknown_name)).to be_nil
    end

    it "should accept unqualified account name" do
      expect(subject.name_to_sid('SYSTEM')).to eq(sid)
    end

    it "should return a SID for a passed user or group name" do
      subject.expects(:name_to_sid_object).with('testers').returns stub(:sid => 'S-1-5-32-547')
      expect(subject.name_to_sid('testers')).to eq('S-1-5-32-547')
    end

    it "should return a SID for a passed fully-qualified user or group name" do
      subject.expects(:name_to_sid_object).with('MACHINE\testers').returns stub(:sid => 'S-1-5-32-547')
      expect(subject.name_to_sid('MACHINE\testers')).to eq('S-1-5-32-547')
    end

    it "should be case-insensitive" do
      expect(subject.name_to_sid('SYSTEM')).to eq(subject.name_to_sid('system'))
    end

    it "should be leading and trailing whitespace-insensitive" do
      expect(subject.name_to_sid('SYSTEM')).to eq(subject.name_to_sid(' SYSTEM '))
    end

    it "should accept domain qualified account names" do
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

  context "#name_to_sid_object" do
    it "should return nil if the account does not exist" do
      expect(subject.name_to_sid_object(unknown_name)).to be_nil
    end

    it "should return a Puppet::Util::Windows::SID::Principal instance for any valid sid" do
      expect(subject.name_to_sid_object(sid)).to be_an_instance_of(Puppet::Util::Windows::SID::Principal)
    end

    it "should accept unqualified account name" do
      expect(subject.name_to_sid_object('SYSTEM').sid).to eq(sid)
    end

    it "should be case-insensitive" do
      expect(subject.name_to_sid_object('SYSTEM')).to eq(subject.name_to_sid_object('system'))
    end

    it "should be leading and trailing whitespace-insensitive" do
      expect(subject.name_to_sid_object('SYSTEM')).to eq(subject.name_to_sid_object(' SYSTEM '))
    end

    it "should accept domain qualified account names" do
      expect(subject.name_to_sid_object('NT AUTHORITY\SYSTEM').sid).to eq(sid)
    end
  end

  context "#sid_to_name" do
    it "should return nil if given a sid for an account that doesn't exist" do
      expect(subject.sid_to_name(unknown_sid)).to be_nil
    end

    it "should accept a sid" do
      expect(subject.sid_to_name(sid)).to eq("NT AUTHORITY\\SYSTEM")
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
