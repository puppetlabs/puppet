require 'spec_helper'

describe "TestHelper" do
  context "#after_each_test" do
    it "restores the original environment" do
      varname = 'test_helper_spec-test_variable'
      ENV[varname] = "\u16A0"

      expect(ENV[varname]).to eq("\u16A0")

      # Prematurely trigger the after_each_test method
      Puppet::Test::TestHelper.after_each_test

      expect(ENV[varname]).to be_nil
    end
  end
end
