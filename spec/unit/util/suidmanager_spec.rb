#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Util::SUIDManager do
  let :user do
    Puppet::Type.type(:user).new(:name => 'name', :uid => 42, :gid => 42)
  end

  let :xids do
    Hash.new {|h,k| 0}
  end

  before :each do
    Puppet::Util::SUIDManager.stubs(:convert_xid).returns(42)
    Puppet::Util::SUIDManager.stubs(:initgroups)

    [:euid, :egid, :uid, :gid, :groups].each do |id|
      Process.stubs("#{id}=").with {|value| xids[id] = value}
    end
  end

  describe "#uid" do
    it "should allow setting euid/egid" do
      Puppet::Util::SUIDManager.egid = user[:gid]
      Puppet::Util::SUIDManager.euid = user[:uid]

      xids[:egid].should == user[:gid]
      xids[:euid].should == user[:uid]
    end
  end

  describe "#asuser" do
    it "should set euid/egid when root" do
      Process.stubs(:uid).returns(0)

      Process.stubs(:euid).returns(50)
      Process.stubs(:egid).returns(50)

      yielded = false
      Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) do
        xids[:egid].should == user[:gid]
        xids[:euid].should == user[:uid]
        yielded = true
      end

      xids[:egid].should == 50
      xids[:euid].should == 50

      # It's possible asuser could simply not yield, so the assertions in the
      # block wouldn't fail. So verify those actually got checked.
      yielded.should be_true
    end

    it "should not get or set euid/egid when not root" do
      Process.stubs(:uid).returns(1)

      Process.stubs(:euid).returns(50)
      Process.stubs(:egid).returns(50)

      Puppet::Util::SUIDManager.asuser(user[:uid], user[:gid]) {}

      xids.should be_empty
    end
  end

  describe "when running commands" do
    before :each do
      # We want to make sure $CHILD_STATUS is set
      Kernel.system '' if $CHILD_STATUS.nil?
    end

    describe "with #system" do
      it "should set euid/egid when root" do
        Process.stubs(:uid).returns(0)
        Process.stubs(:groups=)
        Process.expects(:euid).returns(99997)
        Process.expects(:egid).returns(99996)

        Process.expects(:euid=).with(uid)
        Process.expects(:egid=).with(gid)

        Kernel.expects(:system).with('blah')
        Puppet::Util::SUIDManager.system('blah', user[:uid], user[:gid])

        xids[:egid].should == 99996
        xids[:euid].should == 99997
      end

      it "should not get or set euid/egid when not root" do
        Process.stubs(:uid).returns(1)
        Kernel.expects(:system).with('blah')

        Puppet::Util::SUIDManager.system('blah', user[:uid], user[:gid])

        xids.should be_empty
      end
    end

    describe "with #run_and_capture" do
      it "should capture the output and return process status" do
        Puppet::Util.
          expects(:execute).
          with('yay', :combine => true, :failonfail => false, :uid => user[:uid], :gid => user[:gid]).
          returns('output')
        output = Puppet::Util::SUIDManager.run_and_capture 'yay', user[:uid], user[:gid]

        output.first.should == 'output'
        output.last.should be_a(Process::Status)
      end
    end
  end
end
