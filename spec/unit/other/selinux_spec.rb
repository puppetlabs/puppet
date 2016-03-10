#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/type/selboolean'
require 'puppet/type/selmodule'

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

describe Puppet::Type.type(:selboolean), " when manipulating booleans" do
  before :each do
    provider_class = Puppet::Type::Selboolean.provider(Puppet::Type::Selboolean.providers[0])
    Puppet::Type::Selboolean.stubs(:defaultprovider).returns provider_class

    @bool = Puppet::Type::Selboolean.new(
      :name => "foo",
      :value => "on",
      :persistent => true )
  end

  it "should be able to access :name" do
    expect(@bool[:name]).to eq("foo")
  end

  it "should be able to access :value" do
    expect(@bool.property(:value).should).to eq(:on)
  end

  it "should set :value to off" do
    @bool[:value] = :off
    expect(@bool.property(:value).should).to eq(:off)
  end

  it "should be able to access :persistent" do
    expect(@bool[:persistent]).to eq(:true)
  end

  it "should set :persistent to false" do
    @bool[:persistent] = false
    expect(@bool[:persistent]).to eq(:false)
  end
end

describe Puppet::Type.type(:selmodule), " when checking policy modules" do
  before :each do
    provider_class = Puppet::Type::Selmodule.provider(Puppet::Type::Selmodule.providers[0])
    Puppet::Type::Selmodule.stubs(:defaultprovider).returns provider_class

    @module = Puppet::Type::Selmodule.new(
      :name => "foo",
      :selmoduledir => "/some/path",
      :selmodulepath => "/some/path/foo.pp",
      :syncversion => true)
  end

  it "should be able to access :name" do
    expect(@module[:name]).to eq("foo")
  end

  it "should be able to access :selmoduledir" do
    expect(@module[:selmoduledir]).to eq("/some/path")
  end

  it "should be able to access :selmodulepath" do
    expect(@module[:selmodulepath]).to eq("/some/path/foo.pp")
  end

  it "should be able to access :syncversion" do
    expect(@module[:syncversion]).to eq(:true)
  end

  it "should set the syncversion value to false" do
    @module[:syncversion] = :false
    expect(@module[:syncversion]).to eq(:false)
  end
end
