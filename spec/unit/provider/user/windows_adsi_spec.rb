#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:user).provider(:windows_adsi), :if => Puppet.features.microsoft_windows? do
  let(:resource) do
    Puppet::Type.type(:user).new(
      :title => 'testuser',
      :comment => 'Test J. User',
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
    it "should enumerate all users" do
      names = ['user1', 'user2', 'user3']
      stub_users = names.map{|n| stub(:name => n)}
      connection.stubs(:execquery).with('select name from win32_useraccount where localaccount = "TRUE"').returns(stub_users)

      described_class.instances.map(&:name).should =~ names
    end
  end

  it "should provide access to a Puppet::Util::Windows::ADSI::User object" do
    provider.user.should be_a(Puppet::Util::Windows::ADSI::User)
  end

  describe "when managing groups" do
    it 'should return the list of groups as a comma-separated list' do
      provider.user.stubs(:groups).returns ['group1', 'group2', 'group3']

      provider.groups.should == 'group1,group2,group3'
    end

    it "should return absent if there are no groups" do
      provider.user.stubs(:groups).returns []

      provider.groups.should == ''
    end

    it 'should be able to add a user to a set of groups' do
      resource[:membership] = :minimum
      provider.user.expects(:set_groups).with('group1,group2', true)

      provider.groups = 'group1,group2'

      resource[:membership] = :inclusive
      provider.user.expects(:set_groups).with('group1,group2', false)

      provider.groups = 'group1,group2'
    end
  end

  describe "when creating a user" do
    it "should create the user on the system and set its other properties" do
      resource[:groups]     = ['group1', 'group2']
      resource[:membership] = :inclusive
      resource[:comment]    = 'a test user'
      resource[:home]       = 'C:\Users\testuser'

      user = stub 'user'
      Puppet::Util::Windows::ADSI::User.expects(:create).with('testuser').returns user

      user.stubs(:groups).returns(['group2', 'group3'])

      create = sequence('create')
      user.expects(:password=).in_sequence(create)
      user.expects(:commit).in_sequence(create)
      user.expects(:set_groups).with('group1,group2', false).in_sequence(create)
      user.expects(:[]=).with('Description', 'a test user')
      user.expects(:[]=).with('HomeDirectory', 'C:\Users\testuser')

      provider.create
    end

    it "should load the profile if managehome is set" do
      resource[:password] = '0xDeadBeef'
      resource[:managehome] = true

      user = stub_everything 'user'
      Puppet::Util::Windows::ADSI::User.expects(:create).with('testuser').returns user
      Puppet::Util::Windows::User.expects(:load_profile).with('testuser', '0xDeadBeef')

      provider.create
    end

    it "should set a user's password" do
      provider.user.expects(:password=).with('plaintextbad')

      provider.password = "plaintextbad"
    end

    it "should test a valid user password" do
      resource[:password] = 'plaintext'
      provider.user.expects(:password_is?).with('plaintext').returns true

      provider.password.should == 'plaintext'

    end

    it "should test a bad user password" do
      resource[:password] = 'plaintext'
      provider.user.expects(:password_is?).with('plaintext').returns false

      provider.password.should == :absent
    end

    it 'should not create a user if a group by the same name exists' do
      Puppet::Util::Windows::ADSI::User.expects(:create).with('testuser').raises( Puppet::Error.new("Cannot create user if group 'testuser' exists.") )
      expect{ provider.create }.to raise_error( Puppet::Error,
        /Cannot create user if group 'testuser' exists./ )
    end

    it "should fail with an actionable message when trying to create an active directory user" do
      resource[:name] = 'DOMAIN\testdomainuser'
      Puppet::Util::Windows::ADSI::Group.expects(:exists?).with(resource[:name]).returns(false)
      connection.expects(:Create)
      connection.expects(:Get).with('UserFlags')
      connection.expects(:Put).with('UserFlags', true)
      connection.expects(:SetInfo).raises( WIN32OLERuntimeError.new("(in OLE method `SetInfo': )\n    OLE error code:8007089A in Active Directory\n      The specified username is invalid.\r\n\n    HRESULT error code:0x80020009\n      Exception occurred."))

      expect{ provider.create }.to raise_error(
        Puppet::Error,
        /not able to create\/delete domain users/
      )
    end
  end

  it 'should be able to test whether a user exists' do
    Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
    Puppet::Util::Windows::ADSI.stubs(:connect).returns stub('connection')
    provider.should be_exists

    Puppet::Util::Windows::ADSI.stubs(:connect).returns nil
    provider.should_not be_exists
  end

  it 'should be able to delete a user' do
    connection.expects(:Delete).with('user', 'testuser')

    provider.delete
  end

  it 'should not run commit on a deleted user' do
    connection.expects(:Delete).with('user', 'testuser')
    connection.expects(:SetInfo).never

    provider.delete
    provider.flush
  end

  it 'should delete the profile if managehome is set' do
    resource[:managehome] = true

    sid = 'S-A-B-C'
    Puppet::Util::Windows::SID.expects(:name_to_sid).with('testuser').returns(sid)
    Puppet::Util::Windows::ADSI::UserProfile.expects(:delete).with(sid)
    connection.expects(:Delete).with('user', 'testuser')

    provider.delete
  end

  it "should commit the user when flushed" do
    provider.user.expects(:commit)

    provider.flush
  end

  it "should return the user's SID as uid" do
    Puppet::Util::Windows::SID.expects(:name_to_sid).with('testuser').returns('S-1-5-21-1362942247-2130103807-3279964888-1111')

    provider.uid.should == 'S-1-5-21-1362942247-2130103807-3279964888-1111'
  end

  it "should fail when trying to manage the uid property" do
    provider.expects(:fail).with { |msg| msg =~ /uid is read-only/ }
    provider.send(:uid=, 500)
  end

  [:gid, :shell].each do |prop|
    it "should fail when trying to manage the #{prop} property" do
      provider.expects(:fail).with { |msg| msg =~ /No support for managing property #{prop}/ }
      provider.send("#{prop}=", 'foo')
    end
  end
end
