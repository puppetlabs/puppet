#!/usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Util::Windows::SID", :if => Puppet.features.microsoft_windows? do
  if Puppet.features.microsoft_windows?
    require 'puppet/util/windows'
  end

  let(:subject)      { Puppet::Util::Windows::SID }
  let(:sid)          { Win32::Security::SID::LocalSystem }
  let(:invalid_sid)  { 'bogus' }
  let(:unknown_sid)  { 'S-0-0-0' }
  let(:unknown_name) { 'chewbacca' }

  context "#octet_string_to_sid_object" do
    it "should properly convert an array of bytes for a well-known SID" do
      bytes = [1, 1, 0, 0, 0, 0, 0, 5, 18, 0, 0, 0]
      converted = subject.octet_string_to_sid_object(bytes)

      converted.should == Win32::Security::SID.new('SYSTEM')
      converted.should be_an_instance_of Win32::Security::SID
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

    it "should raise an error for a malformed byte array" do
      expect {
        invalid_octet = [1]
        subject.octet_string_to_sid_object(invalid_octet)
      }.to raise_error(SystemCallError, /No mapping between account names and security IDs was done./)
    end
  end

  context "#name_to_sid" do
    it "should return nil if the account does not exist" do
      subject.name_to_sid(unknown_name).should be_nil
    end

    it "should accept unqualified account name" do
      subject.name_to_sid('SYSTEM').should == sid
    end

    it "should be case-insensitive" do
      subject.name_to_sid('SYSTEM').should == subject.name_to_sid('system')
    end

    it "should be leading and trailing whitespace-insensitive" do
      subject.name_to_sid('SYSTEM').should == subject.name_to_sid(' SYSTEM ')
    end

    it "should accept domain qualified account names" do
      subject.name_to_sid('NT AUTHORITY\SYSTEM').should == sid
    end

    it "should be the identity function for any sid" do
      subject.name_to_sid(sid).should == sid
    end
  end

  context "#name_to_sid_object" do
    it "should return nil if the account does not exist" do
      subject.name_to_sid_object(unknown_name).should be_nil
    end

    it "should return a Win32::Security::SID instance for any valid sid" do
      subject.name_to_sid_object(sid).should be_an_instance_of(Win32::Security::SID)
    end

    it "should accept unqualified account name" do
      subject.name_to_sid_object('SYSTEM').to_s.should == sid
    end

    it "should be case-insensitive" do
      subject.name_to_sid_object('SYSTEM').should == subject.name_to_sid_object('system')
    end

    it "should be leading and trailing whitespace-insensitive" do
      subject.name_to_sid_object('SYSTEM').should == subject.name_to_sid_object(' SYSTEM ')
    end

    it "should accept domain qualified account names" do
      subject.name_to_sid_object('NT AUTHORITY\SYSTEM').to_s.should == sid
    end
  end

  context "#sid_to_name" do
    it "should return nil if given a sid for an account that doesn't exist" do
      subject.sid_to_name(unknown_sid).should be_nil
    end

    it "should accept a sid" do
      subject.sid_to_name(sid).should == "NT AUTHORITY\\SYSTEM"
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
      string.should == sid
    end
  end

  context "#string_to_sid_ptr" do
    it "should yield sid_ptr" do
      ptr = nil
      subject.string_to_sid_ptr(sid) do |p|
        ptr = p
      end
      ptr.should_not be_nil
    end

    it "should raise on an invalid sid" do
      expect {
        subject.string_to_sid_ptr(invalid_sid)
      }.to raise_error(Puppet::Error, /Failed to convert string SID/)
    end
  end

  context "#valid_sid?" do
    it "should return true for a valid SID" do
      subject.valid_sid?(sid).should be_true
    end

    it "should return false for an invalid SID" do
      subject.valid_sid?(invalid_sid).should be_false
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
