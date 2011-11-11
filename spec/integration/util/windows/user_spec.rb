#!/usr/bin/env rspec

require 'spec_helper'

describe "Puppet::Util::Windows::User", :if => Puppet.features.microsoft_windows? do
  describe "2003 without UAC" do
    before :each do
      Facter.stubs(:value).with(:kernelmajversion).returns("5.2")
    end

    it "should be root if user is a member of the Administrators group" do
      Sys::Admin.stubs(:get_login).returns("Administrator")
      Sys::Group.stubs(:members).returns(%w[Administrator])

      Win32::Security.expects(:elevated_security?).never
      Puppet::Util::Windows::User.should be_admin
    end

    it "should not be root if the process is running as Guest" do
      Sys::Admin.stubs(:get_login).returns("Guest")
      Sys::Group.stubs(:members).returns([])

      Win32::Security.expects(:elevated_security?).never
      Puppet::Util::Windows::User.should_not be_admin
    end

    it "should raise an exception if the process fails to open the process token" do
      Win32::Security.stubs(:elevated_security?).raises(Win32::Security::Error, "Access denied.")
      Sys::Admin.stubs(:get_login).returns("Administrator")
      Sys::Group.expects(:members).never

      lambda { Puppet::Util::Windows::User.should raise_error(Win32::Security::Error, /Access denied./) }
    end
  end

  describe "2008 with UAC" do
    before :each do
      Facter.stubs(:value).with(:kernelmajversion).returns("6.0")
    end

    it "should be root if user is running with elevated privileges" do
      Win32::Security.stubs(:elevated_security?).returns(true)
      Sys::Admin.expects(:get_login).never

      Puppet::Util::Windows::User.should be_admin
    end

    it "should not be root if user is not running with elevated privileges" do
      Win32::Security.stubs(:elevated_security?).returns(false)
      Sys::Admin.expects(:get_login).never

      Puppet::Util::Windows::User.should_not be_admin
    end

    it "should raise an exception if the process fails to open the process token" do
      Win32::Security.stubs(:elevated_security?).raises(Win32::Security::Error, "Access denied.")
      Sys::Admin.expects(:get_login).never

      lambda { Puppet::Util::Windows::User.should raise_error(Win32::Security::Error, /Access denied./) }
    end
  end
end
