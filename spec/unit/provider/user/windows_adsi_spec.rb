#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:user).provider(:windows_adsi) do
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
    Puppet::Util::ADSI.stubs(:computer_name).returns('testcomputername')
    Puppet::Util::ADSI.stubs(:connect).returns connection
  end

  describe ".instances" do
    it "should enumerate all users" do
      names = ['user1', 'user2', 'user3']
      stub_users = names.map{|n| stub(:name => n)}

      connection.stubs(:execquery).with("select * from win32_useraccount").returns(stub_users)

      described_class.instances.map(&:name).should =~ names
    end
  end

  it "should provide access to a Puppet::Util::ADSI::User object" do
    provider.user.should be_a(Puppet::Util::ADSI::User)
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
      Puppet::Util::ADSI::User.expects(:create).with('testuser').returns user

      user.stubs(:groups).returns(['group2', 'group3'])

      user.expects(:set_groups).with('group1,group2', false)
      user.expects(:[]=).with('Description', 'a test user')
      user.expects(:[]=).with('HomeDirectory', 'C:\Users\testuser')

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

  end

  it 'should be able to test whether a user exists' do
    Puppet::Util::ADSI.stubs(:connect).returns stub('connection')
    provider.should be_exists

    Puppet::Util::ADSI.stubs(:connect).returns nil
    provider.should_not be_exists
  end

  it 'should be able to delete a user' do
    connection.expects(:Delete).with('user', 'testuser')

    provider.delete
  end

  it "should commit the user when flushed" do
    provider.user.expects(:commit)

    provider.flush
  end

  it "should return the user's SID as uid" do
    Puppet::Util::ADSI.expects(:sid_for_account).with('testuser').returns('S-1-5-21-1362942247-2130103807-3279964888-1111')

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
