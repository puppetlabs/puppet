#! /usr/bin/env ruby
require 'spec_helper'

describe "Windows UTF8 environment variables", :if => Puppet.features.microsoft_windows? do
  # The Puppet::Util::Windows::Process class is used to manipulate environment variables as it is known to handle UTF8 characters. Where as the implementation of ENV in ruby does not.
  # before and end all are used to inject environment variables before the test helper 'before_each_test' function is called
  # Do not use before and after hooks in these tests as it may have unintended consequences

  before(:all) {
    @varname = 'test_helper_spec-test_variable'
    @rune_utf8 = "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7"

    Puppet::Util::Windows::Process.set_environment_variable(@varname, @rune_utf8)
  }
  after(:all) {
    # Need to cleanup this environment variable otherwise it contaminates any subsequent tests
    Puppet::Util::Windows::Process.set_environment_variable(@varname, nil)
  }
  
  it "#after_each_test should preserve UTF8 environment variables" do
    envhash = Puppet::Util::Windows::Process.get_environment_strings
    expect(envhash[@varname]).to eq(@rune_utf8)
    # Change the value in the test to force test_helper to restore the environment
    ENV[@varname] = 'bad foo'

    # Prematurely trigger the after_each_test method
    Puppet::Test::TestHelper.after_each_test

    envhash = Puppet::Util::Windows::Process.get_environment_strings
    expect(envhash[@varname]).to eq(@rune_utf8)
  end
end
