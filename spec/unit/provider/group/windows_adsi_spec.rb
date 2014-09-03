#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:group).provider(:windows_adsi), :if => Puppet.features.microsoft_windows? do
  let(:resource) do
    Puppet::Type.type(:group).new(
      :title => 'testers',
      :provider => :windows_adsi
    )
  end

  let(:provider) { resource.provider }

  let(:connection) { stub 'connection' }

  before :each do
    Puppet::Util::Windows::ADSI.stubs(:computer_name).returns('testcomputername')
    Puppet::Util::Windows::ADSI.stubs(:connect).returns connection
  end

  describe ".instances" do
    it "should enumerate all groups" do
      names = ['group1', 'group2', 'group3']
      stub_groups = names.map{|n| stub(:name => n)}

      connection.stubs(:execquery).with('select name from win32_group where localaccount = "TRUE"').returns stub_groups

      described_class.instances.map(&:name).should =~ names
    end
  end

  describe "group type :members property helpers" do

    let(:user1) { stub(:account => 'user1', :domain => '.', :to_s => 'user1sid') }
    let(:user2) { stub(:account => 'user2', :domain => '.', :to_s => 'user2sid') }

    before :each do
      Puppet::Util::Windows::SID.stubs(:name_to_sid_object).with('user1').returns(user1)
      Puppet::Util::Windows::SID.stubs(:name_to_sid_object).with('user2').returns(user2)
    end

    describe "#members_insync?" do
      it "should return false when current is nil" do
        provider.members_insync?(nil, ['user2']).should be_false
      end
      it "should return false when should is nil" do
        provider.members_insync?(['user1'], nil).should be_false
      end
      it "should return false for differing lists of members" do
        provider.members_insync?(['user1'], ['user2']).should be_false
        provider.members_insync?(['user1'], []).should be_false
        provider.members_insync?([], ['user2']).should be_false
      end
      it "should return true for same lists of members" do
        provider.members_insync?(['user1', 'user2'], ['user1', 'user2']).should be_true
      end
      it "should return true for same lists of unordered members" do
        provider.members_insync?(['user1', 'user2'], ['user2', 'user1']).should be_true
      end
      it "should return true for same lists of members irrespective of duplicates" do
        provider.members_insync?(['user1', 'user2', 'user2'], ['user2', 'user1', 'user1']).should be_true
      end
    end

    describe "#members_to_s" do
      it "should return an empty string on non-array input" do
        [Object.new, {}, 1, :symbol, ''].each do |input|
          provider.members_to_s(input).should be_empty
        end
      end
      it "should return an empty string on empty or nil users" do
        provider.members_to_s([]).should be_empty
        provider.members_to_s(nil).should be_empty
      end
      it "should return a user string like DOMAIN\\USER" do
        provider.members_to_s(['user1']).should == '.\user1'
      end
      it "should return a user string like DOMAIN\\USER,DOMAIN2\\USER2" do
        provider.members_to_s(['user1', 'user2']).should == '.\user1,.\user2'
      end
    end
  end

  describe "when managing members" do
    it "should be able to provide a list of members" do
      provider.group.stubs(:members).returns ['user1', 'user2', 'user3']

      provider.members.should =~ ['user1', 'user2', 'user3']
    end

    it "should be able to set group members" do
      provider.group.stubs(:members).returns ['user1', 'user2']

      member_sids = [
        stub(:account => 'user1', :domain => 'testcomputername'),
        stub(:account => 'user2', :domain => 'testcomputername'),
        stub(:account => 'user3', :domain => 'testcomputername'),
      ]

      provider.group.stubs(:member_sids).returns(member_sids[0..1])

      Puppet::Util::Windows::SID.expects(:name_to_sid_object).with('user2').returns(member_sids[1])
      Puppet::Util::Windows::SID.expects(:name_to_sid_object).with('user3').returns(member_sids[2])

      provider.group.expects(:remove_member_sids).with(member_sids[0])
      provider.group.expects(:add_member_sids).with(member_sids[2])

      provider.members = ['user2', 'user3']
    end
  end

  describe 'when creating groups' do
    it "should be able to create a group" do
      resource[:members] = ['user1', 'user2']

      group = stub 'group'
      Puppet::Util::Windows::ADSI::Group.expects(:create).with('testers').returns group

      create = sequence('create')
      group.expects(:commit).in_sequence(create)
      group.expects(:set_members).with(['user1', 'user2']).in_sequence(create)

      provider.create
    end

    it 'should not create a group if a user by the same name exists' do
      Puppet::Util::Windows::ADSI::Group.expects(:create).with('testers').raises( Puppet::Error.new("Cannot create group if user 'testers' exists.") )
      expect{ provider.create }.to raise_error( Puppet::Error,
        /Cannot create group if user 'testers' exists./ )
    end

    it 'should commit a newly created group' do
      provider.group.expects( :commit )

      provider.flush
    end
  end

  it "should be able to test whether a group exists" do
    Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
    Puppet::Util::Windows::ADSI.stubs(:connect).returns stub('connection')
    provider.should be_exists

    Puppet::Util::Windows::ADSI.stubs(:connect).returns nil
    provider.should_not be_exists
  end

  it "should be able to delete a group" do
    connection.expects(:Delete).with('group', 'testers')

    provider.delete
  end

  it "should report the group's SID as gid" do
    Puppet::Util::Windows::SID.expects(:name_to_sid).with('testers').returns('S-1-5-32-547')
    provider.gid.should == 'S-1-5-32-547'
  end

  it "should fail when trying to manage the gid property" do
    provider.expects(:fail).with { |msg| msg =~ /gid is read-only/ }
    provider.send(:gid=, 500)
  end

  it "should prefer the domain component from the resolved SID" do
    provider.members_to_s(['.\Administrators']).should == 'BUILTIN\Administrators'
  end
end
