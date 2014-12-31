#!/usr/bin/env ruby
require 'spec_helper'
require 'etc'
require 'pp'

provider_class = Puppet::Type.type(:user).provider(:hpuxuseradd)

describe provider_class do
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

  context "managing passwords 2" do
    let :pwent do
      Struct::Passwd.new("root", "bazpassword")
    end
    before :each do
      Etc.stubs(:getpwent).returns(pwent)
      Etc.stubs(:getpwnam).returns(pwent)
    end

     it "Should have feature manages_password_age" do
        provider_class.should be_manages_password_age
     end

     it "Should have feature manages_expiry" do
        provider_class.should be_manages_expiry
     end


     it "should return modprpw for password aging on trusted systems" do
        if provider.trusted == "Trusted"
           provider_class.command(:password).should == "/usr/lbin/modprpw"
        end
     end

    it "Should be able to test for trusted computing" do
      #provider.trusted.should be ("Trusted").or("NotTrusted")
      provider.trusted.should_not be_nil
    end

    it "Should return min age for user if trusted system" do
       if provider.trusted == "Trusted"
          provider.password_min_age.should_not be_nil
       end
    end

    it "Should return max age for user if trusted system" do
       if provider.trusted == "Trusted"
          provider.password_max_age.should_not be_nil
       end
    end

  it "should add /usr/lbin/modprpw -v -l when modifying user if trusted" do
    if provider.trust2
       resource.stubs(:allowdupe?).returns true
       provider.expects(:execute).with() { |args|  args.include?('/usr/lbin/modprpw') and args.include?("-v") and args.include?("-l") }
       provider.uid = 1000
    end
  end
 end
end
