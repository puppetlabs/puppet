#!/usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Util::Windows::SID", :if => Puppet.features.microsoft_windows? do
  if Puppet.features.microsoft_windows?
    require 'puppet/util/windows'
    class SIDTester
      include Puppet::Util::Windows::SID
    end
  end

  let(:subject)      { SIDTester.new }
  let(:sid)          { Win32::Security::SID::LocalSystem }
  let(:invalid_sid)  { 'bogus' }
  let(:unknown_sid)  { 'S-0-0-0' }
  let(:unknown_name) { 'chewbacca' }

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

    it "should accept domain qualified account names" do
      subject.name_to_sid('NT AUTHORITY\SYSTEM').should == sid
    end

    it "should be the identity function for any sid" do
      subject.name_to_sid(sid).should == sid
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
        raises(Puppet::Util::Windows::Error.new("Failed to convert string SID: #{sid}", Windows::Error::ERROR_ACCESS_DENIED))

      expect {
        subject.string_to_sid_ptr(sid) {|ptr| }
      }.to raise_error(Puppet::Util::Windows::Error, /Failed to convert string SID: #{sid}/)
    end
  end
end
