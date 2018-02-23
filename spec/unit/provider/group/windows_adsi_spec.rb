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
    # this would normally query the system, but not needed for these tests
    Puppet::Util::Windows::ADSI::Group.stubs(:localized_domains).returns([])
  end

  describe ".instances" do
    it "should enumerate all groups" do
      names = ['group1', 'group2', 'group3']
      stub_groups = names.map{|n| stub(:name => n)}

      connection.stubs(:execquery).with('select name from win32_group where localaccount = "TRUE"').returns stub_groups

      expect(described_class.instances.map(&:name)).to match(names)
    end
  end

  describe "group type :members property helpers" do

    let(:user1) { stub(:account => 'user1', :domain => '.', :sid => 'user1sid') }
    let(:user2) { stub(:account => 'user2', :domain => '.', :sid => 'user2sid') }
    let(:user3) { stub(:account => 'user3', :domain => '.', :sid => 'user3sid') }
    let(:invalid_user) { SecureRandom.uuid }

    before :each do
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with('user1').returns(user1)
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with('user2').returns(user2)
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with('user3').returns(user3)
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with(invalid_user).returns(nil)
    end

    describe "#members_insync?" do
      it "should return true for same lists of members" do
        current = [
          Puppet::Util::Windows::SID.name_to_principal('user1'),
          Puppet::Util::Windows::SID.name_to_principal('user2'),
        ]
        expect(provider.members_insync?(current, ['user1', 'user2'])).to be_truthy
      end

      it "should return true for same lists of unordered members" do
        current = [
          Puppet::Util::Windows::SID.name_to_principal('user1'),
          Puppet::Util::Windows::SID.name_to_principal('user2'),
        ]
        expect(provider.members_insync?(current, ['user2', 'user1'])).to be_truthy
      end

      it "should return true for same lists of members irrespective of duplicates" do
        current = [
          Puppet::Util::Windows::SID.name_to_principal('user1'),
          Puppet::Util::Windows::SID.name_to_principal('user2'),
          Puppet::Util::Windows::SID.name_to_principal('user2'),
        ]
        expect(provider.members_insync?(current, ['user2', 'user1', 'user1'])).to be_truthy
      end

      it "should return true when current and should members are empty lists" do
        expect(provider.members_insync?([], [])).to be_truthy
      end

      # invalid scenarios
      #it "should return true when current and should members are nil lists" do
      #it "should return true when current members is nil and should members is empty" do

      it "should return true when current members is empty and should members is nil" do
        expect(provider.members_insync?([], nil)).to be_truthy
      end

      context "when auth_membership => true" do
        before :each do
          resource[:auth_membership] = true
        end

        it "should return true when current and should contain the same users in a different order" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
            Puppet::Util::Windows::SID.name_to_principal('user2'),
            Puppet::Util::Windows::SID.name_to_principal('user3'),
          ]
          expect(provider.members_insync?(current, ['user3', 'user1', 'user2'])).to be_truthy
        end

        it "should return false when current is nil" do
          expect(provider.members_insync?(nil, ['user2'])).to be_falsey
        end

        it "should return false when should is nil" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
          ]
          expect(provider.members_insync?(current, nil)).to be_falsey
        end

        it "should return false when current contains different users than should" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
          ]
          expect(provider.members_insync?(current, ['user2'])).to be_falsey
        end

        it "should return false when current contains members and should is empty" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
          ]
          expect(provider.members_insync?(current, [])).to be_falsey
        end

        it "should return false when current is empty and should contains members" do
          expect(provider.members_insync?([], ['user2'])).to be_falsey
        end

        it "should return false when should user(s) are not the only items in the current" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
            Puppet::Util::Windows::SID.name_to_principal('user2'),
          ]
          expect(provider.members_insync?(current, ['user1'])).to be_falsey
        end

        it "should return false when current user(s) is not empty and should is an empty list" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
            Puppet::Util::Windows::SID.name_to_principal('user2'),
          ]
          expect(provider.members_insync?(current, [])).to be_falsey
        end
      end

      context "when auth_membership => false" do
        before :each do
          # this is also the default
          resource[:auth_membership] = false
        end

        it "should return false when current is nil" do
          expect(provider.members_insync?(nil, ['user2'])).to be_falsey
        end

        it "should return true when should is nil" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
          ]
          expect(provider.members_insync?(current, nil)).to be_truthy
        end

        it "should return false when current contains different users than should" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
          ]
          expect(provider.members_insync?(current, ['user2'])).to be_falsey
        end

        it "should return true when current contains members and should is empty" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
          ]
          expect(provider.members_insync?(current, [])).to be_truthy
        end

        it "should return false when current is empty and should contains members" do
          expect(provider.members_insync?([], ['user2'])).to be_falsey
        end

        it "should return true when current user(s) contains at least the should list" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
            Puppet::Util::Windows::SID.name_to_principal('user2'),
          ]
          expect(provider.members_insync?(current, ['user1'])).to be_truthy
        end

        it "should return true when current user(s) is not empty and should is an empty list" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user1'),
            Puppet::Util::Windows::SID.name_to_principal('user2'),
          ]
          expect(provider.members_insync?(current, [])).to be_truthy
        end

        it "should return true when current user(s) contains at least the should list, even unordered" do
          current = [
            Puppet::Util::Windows::SID.name_to_principal('user3'),
            Puppet::Util::Windows::SID.name_to_principal('user1'),
            Puppet::Util::Windows::SID.name_to_principal('user2'),
          ]
          expect(provider.members_insync?(current, ['user2','user1'])).to be_truthy
        end
      end
    end

    describe "#members_to_s" do
      it "should return an empty string on non-array input" do
        [Object.new, {}, 1, :symbol, ''].each do |input|
          expect(provider.members_to_s(input)).to be_empty
        end
      end
      it "should return an empty string on empty or nil users" do
        expect(provider.members_to_s([])).to be_empty
        expect(provider.members_to_s(nil)).to be_empty
      end
      it "should return a user string like DOMAIN\\USER" do
        expect(provider.members_to_s(['user1'])).to eq('.\user1')
      end
      it "should return a user string like DOMAIN\\USER,DOMAIN2\\USER2" do
        expect(provider.members_to_s(['user1', 'user2'])).to eq('.\user1,.\user2')
      end
      it "should return the username when it cannot be resolved to a SID (for the sake of resource_harness error messages)" do
        expect(provider.members_to_s([invalid_user])).to eq("#{invalid_user}")
      end
      it "should return the username when it cannot be resolved to a SID (for the sake of resource_harness error messages)" do
        expect(provider.members_to_s([invalid_user])).to eq("#{invalid_user}")
      end
    end
  end

  describe "when managing members" do
    before :each do
      resource[:auth_membership] = true
    end

    it "should be able to provide a list of members" do
      provider.group.stubs(:members).returns ['user1', 'user2', 'user3']

      expect(provider.members).to match_array(['user1', 'user2', 'user3'])
    end

    it "should be able to set group members" do
      provider.group.stubs(:members).returns ['user1', 'user2']

      member_sids = [
        stub(:account => 'user1', :domain => 'testcomputername', :sid => 1),
        stub(:account => 'user2', :domain => 'testcomputername', :sid => 2),
        stub(:account => 'user3', :domain => 'testcomputername', :sid => 3),
      ]

      provider.group.stubs(:member_sids).returns(member_sids[0..1])

      Puppet::Util::Windows::SID.expects(:name_to_principal).with('user2').returns(member_sids[1])
      Puppet::Util::Windows::SID.expects(:name_to_principal).with('user3').returns(member_sids[2])

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
      # due to PUP-1967, defaultto false will set the default to nil
      group.expects(:set_members).with(['user1', 'user2'], nil).in_sequence(create)

      provider.create
    end

    it 'should not create a group if a user by the same name exists' do
      Puppet::Util::Windows::ADSI::Group.expects(:create).with('testers').raises( Puppet::Error.new("Cannot create group if user 'testers' exists.") )
      expect{ provider.create }.to raise_error( Puppet::Error,
        /Cannot create group if user 'testers' exists./ )
    end

    it "should fail with an actionable message when trying to create an active directory group" do
      resource[:name] = 'DOMAIN\testdomaingroup'
      Puppet::Util::Windows::ADSI::User.expects(:exists?).with(resource[:name]).returns(false)
      connection.expects(:Create)
      connection.expects(:SetInfo).raises( WIN32OLERuntimeError.new("(in OLE method `SetInfo': )\n    OLE error code:8007089A in Active Directory\n      The specified username is invalid.\r\n\n    HRESULT error code:0x80020009\n      Exception occurred."))

      expect{ provider.create }.to raise_error(
                                       Puppet::Error,
                                       /not able to create\/delete domain groups/
                                   )
    end

    it 'should commit a newly created group' do
      provider.group.expects( :commit )

      provider.flush
    end
  end

  it "should be able to test whether a group exists" do
    Puppet::Util::Windows::SID.stubs(:name_to_principal).returns(nil)
    Puppet::Util::Windows::ADSI.stubs(:connect).returns stub('connection', :Class => 'Group')
    expect(provider).to be_exists

    Puppet::Util::Windows::ADSI.stubs(:connect).returns nil
    expect(provider).not_to be_exists
  end

  it "should be able to delete a group" do
    connection.expects(:Delete).with('group', 'testers')

    provider.delete
  end

  it 'should not run commit on a deleted group' do
    connection.expects(:Delete).with('group', 'testers')
    connection.expects(:SetInfo).never

    provider.delete
    provider.flush
  end

  it "should report the group's SID as gid" do
    Puppet::Util::Windows::SID.expects(:name_to_sid).with('testers').returns('S-1-5-32-547')
    expect(provider.gid).to eq('S-1-5-32-547')
  end

  it "should fail when trying to manage the gid property" do
    provider.expects(:fail).with { |msg| msg =~ /gid is read-only/ }
    provider.send(:gid=, 500)
  end

  it "should prefer the domain component from the resolved SID" do
    # must lookup well known S-1-5-32-544 as actual 'Administrators' name may be localized
    admins_sid_bytes = [1, 2, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0, 32, 2, 0, 0]
    admins_group = Puppet::Util::Windows::SID::Principal.lookup_account_sid(admins_sid_bytes)
    # prefix just the name like .\Administrators
    converted = provider.members_to_s([".\\#{admins_group.account}"])

    # and ensure equivalent of BUILTIN\Administrators, without a leading .
    expect(converted).to eq(admins_group.domain_account)
    expect(converted[0]).to_not eq('.')
  end
end
