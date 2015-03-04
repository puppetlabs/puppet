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
    before do
       provider.stubs(:exists?).returns(false)
    end

    it "should add -o when allowdupe is enabled and the group is being created" do
      resource[:allowdupe] = :true
      provider.expects(:execute).with(['/usr/sbin/groupadd', '-o', 'mygroup'], kind_of(Hash))
      provider.create
    end

    describe "on system that feature system_groups", :if => described_class.system_groups? do
      it "should add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        provider.expects(:execute).with(['/usr/sbin/groupadd', '-r', 'mygroup'], kind_of(Hash))
        provider.create
      end
    end

    describe "on system that do not feature system_groups", :unless => described_class.system_groups? do
      it "should not add -r when system is enabled and the group is being created" do
        resource[:system] = :true
        provider.expects(:execute).with(['/usr/sbin/groupadd', 'mygroup'], kind_of(Hash))
        provider.create
      end
    end

    describe "on systems with the libuser and forcelocal=true" do
      before do
        described_class.has_feature(:libuser)
        resource[:forcelocal] = :true
      end
 
      it "should use lgroupadd instead of groupadd" do
        provider.expects(:execute).with(includes('/usr/sbin/lgroupadd'), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.create
      end

      it "should NOT pass -o to lgroupadd" do
        resource[:allowdupe] = :true
        provider.expects(:execute).with(Not(includes('-o')), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.create
      end

      it "should raise an exception for duplicate GID if allowdupe is not set and duplicate GIDs exist" do
        resource[:gid] = 505
        provider.stubs(:findgroup).returns(true)
        expect { provider.create }.to raise_error(Puppet::Error, "GID 505 already exists, use allowdupe to force group creation")
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

