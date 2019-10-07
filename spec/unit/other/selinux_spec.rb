require 'spec_helper'

describe Puppet::Type.type(:file), " when manipulating file contexts" do
  include PuppetSpec::Files

  before :each do

    @file = Puppet::Type::File.new(
      :name => make_absolute("/tmp/foo"),
      :ensure => "file",
      :seluser => "user_u",
      :selrole => "role_r",
      :seltype => "type_t")
  end

  it "should use :seluser to get/set an SELinux user file context attribute" do
    expect(@file[:seluser]).to eq("user_u")
  end

  it "should use :selrole to get/set an SELinux role file context attribute" do
    expect(@file[:selrole]).to eq("role_r")
  end

  it "should use :seltype to get/set an SELinux user file context attribute" do
    expect(@file[:seltype]).to eq("type_t")
  end
end
