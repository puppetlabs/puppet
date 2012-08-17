#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:group).provider(:groupadd) do
  before do
    described_class.stubs(:command).with(:add).returns '/usr/sbin/groupadd'
    described_class.stubs(:command).with(:delete).returns '/usr/sbin/groupdel'
    described_class.stubs(:command).with(:modify).returns '/usr/sbin/groupmod'
  end

  let(:resource) { Puppet::Type.type(:group).new(:name => 'mygroup') }
  let(:provider) { described_class.new(resource) }

  describe "#create" do
    it "should add -o when allowdupe is enabled and the group is being created" do
      resource[:allowdupe] = :true
      provider.expects(:execute).with(['/usr/sbin/groupadd', '-o', 'mygroup'])
      provider.create
    end

    it "should add -r when system is enabled and the group is being created" do
      resource[:system] = :true
      provider.expects(:execute).with(['/usr/sbin/groupadd', '-r', 'mygroup'])
      provider.create
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

