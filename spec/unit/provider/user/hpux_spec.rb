#!/usr/bin/env ruby
require 'spec_helper'
require 'etc'

provider_class = Puppet::Type.type(:user).provider(:hpuxuseradd)

describe provider_class, :unless => Puppet.features.microsoft_windows? do
  let :resource do
    Puppet::Type.type(:user).new(
      :title => 'testuser',
      :comment => 'Test J. User',
      :provider => :hpuxuseradd
    )
  end
  let(:provider) { resource.provider }

  it "should add -F when modifying a user" do
    resource.stubs(:allowdupe?).returns true
    provider.expects(:execute).with { |args| args.include?("-F") }
    provider.uid = 1000
  end

  it "should add -F when deleting a user" do
    provider.stubs(:exists?).returns(true)
    provider.expects(:execute).with { |args| args.include?("-F") }
    provider.delete
  end

  context "managing passwords" do
    let :pwent do
      Struct::Passwd.new("testuser", "foopassword")
    end

    before :each do
      Etc.stubs(:getpwent).returns(pwent)
      Etc.stubs(:getpwnam).returns(pwent)
    end

    it "should have feature manages_passwords" do
      provider_class.should be_manages_passwords
    end

    it "should return nil if user does not exist" do
      Etc.stubs(:getpwent).returns(nil)
      provider.password.must be_nil
    end

    it "should return password entry if exists" do
      provider.password.must == "foopassword"
    end
  end
end
