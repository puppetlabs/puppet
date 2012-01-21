#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:group).provider(:windows_adsi) do
  let(:resource) do
    Puppet::Type.type(:group).new(
      :title => 'testers',
      :provider => :windows_adsi
    )
  end

  let(:provider) { resource.provider }

  let(:connection) { stub 'connection' }

  before :each do
    Puppet::Util::ADSI.stubs(:computer_name).returns('testcomputername')
    Puppet::Util::ADSI.stubs(:connect).returns connection
  end

  describe ".instances" do
    it "should enumerate all groups" do
      names = ['group1', 'group2', 'group3']
      stub_groups = names.map{|n| stub(:name => n)}

      connection.stubs(:execquery).with("select * from win32_group").returns stub_groups

      described_class.instances.map(&:name).should =~ names
    end
  end

  describe "when managing members" do
    it "should be able to provide a list of members" do
      provider.group.stubs(:members).returns ['user1', 'user2', 'user3']

      provider.members.should =~ ['user1', 'user2', 'user3']
    end

    it "should be able to set group members" do
      provider.group.stubs(:members).returns ['user1', 'user2']

      provider.group.expects(:remove_members).with('user1')
      provider.group.expects(:add_members).with('user3')

      provider.members = ['user2', 'user3']
    end
  end

  describe 'when creating groups' do
    it "should be able to create a group" do
      resource[:members] = ['user1', 'user2']

      group = stub 'group'
      Puppet::Util::ADSI::Group.expects(:create).with('testers').returns group

      create = sequence('create')
      group.expects(:commit).in_sequence(create)
      group.expects(:set_members).with(['user1', 'user2']).in_sequence(create)

      provider.create
    end

    it 'should not create a group if a user by the same name exists' do
      Puppet::Util::ADSI::Group.expects(:create).with('testers').raises( Puppet::Error.new("Cannot create group if user 'testers' exists.") )
      expect{ provider.create }.to raise_error( Puppet::Error,
        /Cannot create group if user 'testers' exists./ )
    end

    it 'should commit a newly created group' do
      provider.group.expects( :commit )

      provider.flush
    end
  end

  it "should be able to test whether a group exists" do
    Puppet::Util::ADSI.stubs(:connect).returns stub('connection')
    provider.should be_exists

    Puppet::Util::ADSI.stubs(:connect).returns nil
    provider.should_not be_exists
  end

  it "should be able to delete a group" do
    connection.expects(:Delete).with('group', 'testers')

    provider.delete
  end

  it "should report the group's SID as gid" do
    Puppet::Util::ADSI.expects(:sid_for_account).with('testers').returns('S-1-5-32-547')
    provider.gid.should == 'S-1-5-32-547'
  end

  it "should fail when trying to manage the gid property" do
    provider.expects(:fail).with { |msg| msg =~ /gid is read-only/ }
    provider.send(:gid=, 500)
  end
end
