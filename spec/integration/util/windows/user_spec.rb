#! /usr/bin/env ruby

require 'spec_helper'

describe "Puppet::Util::Windows::User", :if => Puppet.features.microsoft_windows? do
  describe "2003 without UAC" do
    before :each do
      Puppet::Util::Windows::Process.stubs(:windows_major_version).returns(5)
    end

    it "should be an admin if user's token contains the Administrators SID" do
      Puppet::Util::Windows::User.expects(:check_token_membership).returns(true)
      Puppet::Util::Windows::Process.expects(:elevated_security?).never

      expect(Puppet::Util::Windows::User).to be_admin
    end

    it "should not be an admin if user's token doesn't contain the Administrators SID" do
      Puppet::Util::Windows::User.expects(:check_token_membership).returns(false)
      Puppet::Util::Windows::Process.expects(:elevated_security?).never

      expect(Puppet::Util::Windows::User).not_to be_admin
    end

    it "should raise an exception if we can't check token membership" do
      Puppet::Util::Windows::User.expects(:check_token_membership).raises(Puppet::Util::Windows::Error, "Access denied.")
      Puppet::Util::Windows::Process.expects(:elevated_security?).never

      expect { Puppet::Util::Windows::User.admin? }.to raise_error(Puppet::Util::Windows::Error, /Access denied./)
    end
  end

  describe "2008 with UAC" do
    before :each do
      Puppet::Util::Windows::Process.stubs(:windows_major_version).returns(6)
    end

    it "should be an admin if user is running with elevated privileges" do
      Puppet::Util::Windows::Process.stubs(:elevated_security?).returns(true)
      Puppet::Util::Windows::User.expects(:check_token_membership).never

      expect(Puppet::Util::Windows::User).to be_admin
    end

    it "should not be an admin if user is not running with elevated privileges" do
      Puppet::Util::Windows::Process.stubs(:elevated_security?).returns(false)
      Puppet::Util::Windows::User.expects(:check_token_membership).never

      expect(Puppet::Util::Windows::User).not_to be_admin
    end

    it "should raise an exception if the process fails to open the process token" do
      Puppet::Util::Windows::Process.stubs(:elevated_security?).raises(Puppet::Util::Windows::Error, "Access denied.")
      Puppet::Util::Windows::User.expects(:check_token_membership).never

      expect { Puppet::Util::Windows::User.admin? }.to raise_error(Puppet::Util::Windows::Error, /Access denied./)
    end
  end

  describe "module function" do
    let(:username) { 'fabio' }
    let(:bad_password) { 'goldilocks' }
    let(:logon_fail_msg) { /Failed to logon user "fabio":  Logon failure: unknown user name or bad password./ }

    def expect_logon_failure_error(&block)
      expect {
        yield
      }.to raise_error { |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        # https://msdn.microsoft.com/en-us/library/windows/desktop/ms681385(v=vs.85).aspx
        # ERROR_LOGON_FAILURE 1326
        expect(error.code).to eq(1326)
      }
    end

    describe "load_profile" do
      it "should raise an error when provided with an incorrect username and password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.load_profile(username, bad_password)
        }
      end

      it "should raise an error when provided with an incorrect username and nil password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.load_profile(username, nil)
        }
      end
    end

    describe "logon_user" do
      it "should raise an error when provided with an incorrect username and password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.logon_user(username, bad_password)
        }
      end

      it "should raise an error when provided with an incorrect username and nil password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.logon_user(username, nil)
        }
      end
    end

    describe "password_is?" do
      it "should return false given an incorrect username and password" do
        expect(Puppet::Util::Windows::User.password_is?(username, bad_password)).to be_falsey
      end

      it "should return false given an incorrect username and nil password" do
        expect(Puppet::Util::Windows::User.password_is?(username, nil)).to be_falsey
      end

      it "should return false given a nil username and an incorrect password" do
        expect(Puppet::Util::Windows::User.password_is?(nil, bad_password)).to be_falsey
      end
    end

    describe "check_token_membership" do
      it "should not raise an error" do
        # added just to call an FFI code path on all platforms
        expect { Puppet::Util::Windows::User.check_token_membership }.not_to raise_error
      end
    end
  end
end
