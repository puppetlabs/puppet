#! /usr/bin/env ruby

require 'spec_helper'

describe "Puppet::Util::Windows::User", :if => Puppet.features.microsoft_windows? do
  describe "2003 without UAC" do
    before :each do
      Facter.stubs(:value).with(:kernelmajversion).returns("5.2")
    end

    it "should be an admin if user's token contains the Administrators SID" do
      Puppet::Util::Windows::User.expects(:check_token_membership).returns(true)
      Win32::Security.expects(:elevated_security?).never

      Puppet::Util::Windows::User.should be_admin
    end

    it "should not be an admin if user's token doesn't contain the Administrators SID" do
      Puppet::Util::Windows::User.expects(:check_token_membership).returns(false)
      Win32::Security.expects(:elevated_security?).never

      Puppet::Util::Windows::User.should_not be_admin
    end

    it "should raise an exception if we can't check token membership" do
      Puppet::Util::Windows::User.expects(:check_token_membership).raises(Win32::Security::Error, "Access denied.")
      Win32::Security.expects(:elevated_security?).never

      lambda { Puppet::Util::Windows::User.admin? }.should raise_error(Win32::Security::Error, /Access denied./)
    end
  end

  describe "2008 with UAC" do
    before :each do
      Facter.stubs(:value).with(:kernelmajversion).returns("6.0")
    end

    it "should be an admin if user is running with elevated privileges" do
      Win32::Security.stubs(:elevated_security?).returns(true)
      Puppet::Util::Windows::User.expects(:check_token_membership).never

      Puppet::Util::Windows::User.should be_admin
    end

    it "should not be an admin if user is not running with elevated privileges" do
      Win32::Security.stubs(:elevated_security?).returns(false)
      Puppet::Util::Windows::User.expects(:check_token_membership).never

      Puppet::Util::Windows::User.should_not be_admin
    end

    it "should raise an exception if the process fails to open the process token" do
      Win32::Security.stubs(:elevated_security?).raises(Win32::Security::Error, "Access denied.")
      Puppet::Util::Windows::User.expects(:check_token_membership).never

      lambda { Puppet::Util::Windows::User.admin? }.should raise_error(Win32::Security::Error, /Access denied./)
    end
  end
end
