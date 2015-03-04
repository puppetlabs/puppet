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
      resource.stubs(:command).with(:modify).returns '/usr/sam/lbin/usermod.sam'
    end

    it "should have feature manages_passwords" do
      expect(provider_class).to be_manages_passwords
    end

    it "should return nil if user does not exist" do
      Etc.stubs(:getpwent).returns(nil)
      expect(provider.password).to be_nil
    end

    it "should return password entry if exists" do
      expect(provider.password).to eq("foopassword")
    end
  end

  context "check for trusted computing" do
    before :each do
      provider.stubs(:command).with(:modify).returns '/usr/sam/lbin/usermod.sam'
    end

    it "should add modprpw to modifycmd if Trusted System" do
      resource.stubs(:allowdupe?).returns true
      provider.expects(:exec_getprpw).with('root','-m uid').returns('uid=0')
      provider.expects(:execute).with(['/usr/sam/lbin/usermod.sam', '-u', 1000, '-o', 'testuser', '-F', ';', '/usr/lbin/modprpw', '-v', '-l', 'testuser'])
      provider.uid = 1000
    end

    it "should not add modprpw if not Trusted System" do
      resource.stubs(:allowdupe?).returns true
      provider.expects(:exec_getprpw).with('root','-m uid').returns('System is not trusted')
      provider.expects(:execute).with(['/usr/sam/lbin/usermod.sam', '-u', 1000, '-o', 'testuser', '-F'])
      provider.uid = 1000
    end
  end
end
