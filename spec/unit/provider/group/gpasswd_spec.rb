#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:group).provider(:gpasswd) do
  before do
    described_class.stubs(:command).with(:add).returns '/usr/sbin/groupadd'
    described_class.stubs(:command).with(:delete).returns '/usr/sbin/groupdel'
    described_class.stubs(:command).with(:modify).returns '/usr/sbin/groupmod'
    described_class.stubs(:command).with(:addmember).returns '/usr/bin/gpasswd'
    described_class.stubs(:command).with(:delmember).returns '/usr/bin/gpasswd'
  end

  let(:resource) { Puppet::Type.type(:group).new(:name => 'mygroup', :provider => provider) }
  let(:provider) { described_class.new(:name => 'mygroup') }

  describe "#create" do
    it "should add -o when allowdupe is enabled and the group is being created" do
      resource[:allowdupe] = :true
      provider.expects(:execute).with('/usr/sbin/groupadd -o mygroup')
      provider.create
    end

    describe "on system that feature system_groups", :if => described_class.system_groups? do
      it "should add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        provider.expects(:execute).with('/usr/sbin/groupadd -r mygroup')
        provider.create
      end
    end

    describe "on system that do not feature system_groups", :unless => described_class.system_groups? do
      it "should not add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        provider.expects(:execute).with('/usr/sbin/groupadd mygroup')
        provider.create
      end
    end

    describe "when adding additional group members to the group" do
      it "should pass all members individually as group add options to gpasswd" do
        resource[:members] = ['test_one','test_two','test_three']
        provider.expects(:execute).with() { |value|
          value.split(' && ').map{ |x|
            if x =~ /.*\/usr\/bin\/gpasswd -a (.*) mygroup.*/
              x = $1
            end
          }.compact.sort.should == resource[:members].sort
        }
        provider.create
      end
    end

    describe "when adding additional group members to an existing group with members" do
      it "should add all new members and preserve all existing members" do
        old_members = ['old_one','old_two','old_three','test_three']
        Etc.stubs(:getgrnam).with('mygroup').returns(
          Struct::Group.new('mygroup','x','99999',old_members)
        )
        resource[:attribute_membership] = 'minimum'
        resource[:members] = ['test_one','test_two','test_three']
        provider.expects(:execute).with() { |value|
          adds = []
          deletes = []
          value.split(' && ').map{ |x|
            if x =~ /.*\/usr\/bin\/gpasswd -a (.*) mygroup.*/
              adds << $1
            elsif x =~ /.*\/usr\/bin\/gpasswd -d (.*) mygroup.*/
              deletes << $1
            end
          }
          adds.sort.should == ( resource[:members] | old_members ).sort
          deletes.should == []
        }
        provider.create
        provider.members=(resource[:members])
      end
    end

    describe "when adding exclusive group members to an existing group with members" do
      it "should add all new members and delete all, non-matching, existing members" do
        old_members = ['old_one','old_two','old_three','test_three']
        Etc.stubs(:getgrnam).with('mygroup').returns(
          Struct::Group.new('mygroup','x','99999',old_members)
        )
        resource[:attribute_membership] = 'inclusive'
        resource[:members] = ['test_one','test_two','test_three']
        provider.expects(:execute).with() { |value|
          adds = []
          deletes = []
          value.split(' && ').map{ |x|
            if x =~ /.*\/usr\/bin\/gpasswd -a (.*) mygroup.*/
              adds << $1
            elsif x =~ /.*\/usr\/bin\/gpasswd -d (.*) mygroup.*/
              deletes << $1
            end
          }
          adds.sort.should == (resource[:members] - old_members).sort
          deletes.sort.should == (old_members - resource[:members]).sort
        }
        provider.create
        provider.members=(resource[:members])
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

