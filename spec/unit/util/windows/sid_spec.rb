#!/usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Util::Windows::SID", :if => Puppet.features.microsoft_windows? do
  if Puppet.features.microsoft_windows?
    class SIDTester
      include Puppet::Util::Windows::SID
    end
  end

  let(:subject)       { SIDTester.new }
  let(:sid)           { Win32::Security::SID::LocalSystem }
  let(:invalid_sid)   { 'bogus' }

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
    it "should accept well known SID" do
      subject.string_to_sid_ptr(sid).should be_true
    end

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
end
