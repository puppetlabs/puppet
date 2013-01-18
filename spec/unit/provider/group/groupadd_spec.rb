#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:group).provider(:groupadd) do
  before do
    described_class.stubs(:command).with(:add).returns '/usr/sbin/groupadd'
    described_class.stubs(:command).with(:delete).returns '/usr/sbin/groupdel'
    described_class.stubs(:command).with(:modify).returns '/usr/sbin/groupmod'
    described_class.stubs(:command).with(:localadd).returns '/usr/sbin/lgroupadd'
  end

  let(:resource) { Puppet::Type.type(:group).new(:name => 'mygroup', :provider => provider) }
  let(:provider) { described_class.new(:name => 'mygroup') }

  describe "#create" do
    it "should add -o when allowdupe is enabled and the group is being created" do
      resource[:allowdupe] = :true
      provider.expects(:execute).with(['/usr/sbin/groupadd', '-o', 'mygroup'])
      provider.create
    end

    describe "on system that feature system_groups", :if => described_class.system_groups? do
      it "should add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        provider.expects(:execute).with(['/usr/sbin/groupadd', '-r', 'mygroup'])
        provider.create
      end
    end

    describe "on system that do not feature system_groups", :unless => described_class.system_groups? do
      it "should not add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        provider.expects(:execute).with(['/usr/sbin/groupadd', 'mygroup'])
        provider.create
      end
    end

    describe "on systems with the libuser and forcelocal=true" do
      it "should use lgroupadd instead of groupadd" do
        provider.stubs(:feature?).with(:libuser).returns(true)
        resource[:forcelocal] = :true
        provider.expects(:execute).with(includes('/usr/sbin/lgroupadd'))
        provider.create
      end

      it "should NOT pass -o to lgroupadd" do
        resource[:forcelocal] = :true
        resource[:allowdupe] = :true
        provider.expects(:execute).with(Not(includes('-o')))
        provider.create
      end
    end

  end

  describe "#gid=" do
    it "should add -o when allowdupe is enabled and the gid is being modified" do
      resource[:allowdupe] = :true
      provider.expects(:execute).with(['/usr/sbin/groupmod', '-g', 150, '-o', 'mygroup'])
      provider.gid = 150
    end
  end
end

