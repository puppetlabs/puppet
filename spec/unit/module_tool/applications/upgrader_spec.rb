require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

describe Puppet::ModuleTool::Applications::Upgrader do
  include PuppetSpec::Files

  it "should update the requested module"
  it "should not update dependencies"
  it "should fail when updating a dependency to an unsupported version"
  it "should fail when updating a module that is not installed"
  it "should warn when the latest version is already installed"
  it "should warn when the best version is already installed"

  context "when using the '--version' option" do
    it "should update an installed module to the requested version"
  end

  context "when using the '--force' flag" do
    it "should ignore missing dependencies"
    it "should ignore version constraints"
    it "should not update a module that is not installed"
  end

  context "when using the '--env' option" do
    it "should use the correct environment"
  end

  context "when there are missing dependencies" do
    it "should fail to upgrade the original module"
    it "should raise an error"
  end
end
