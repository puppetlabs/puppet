#!/usr/bin/env ruby

require 'spec_helper'

require 'puppet/util/windows'

describe Puppet::Util::Windows::ADSI, :if => Puppet.features.microsoft_windows? do
  let(:connection) { stub 'connection' }

  before(:each) do
    Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, 'testcomputername')
    Puppet::Util::Windows::ADSI.stubs(:connect).returns connection
  end

  after(:each) do
    Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, nil)
  end

  it "should generate the correct URI for a resource" do
    Puppet::Util::Windows::ADSI.uri('test', 'user').should == "WinNT://./test,user"
  end

  it "should be able to get the name of the computer" do
    Puppet::Util::Windows::ADSI.computer_name.should == 'testcomputername'
  end

  it "should be able to provide the correct WinNT base URI for the computer" do
    Puppet::Util::Windows::ADSI.computer_uri.should == "WinNT://."
  end

  it "should generate a fully qualified WinNT URI" do
    Puppet::Util::Windows::ADSI.computer_uri('testcomputername').should == "WinNT://testcomputername"
  end

  describe ".sid_for_account" do
    it "should return nil if the account does not exist" do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('foobar').returns nil

      Puppet::Util::Windows::ADSI.sid_for_account('foobar').should be_nil
    end

    it "should return a SID for a passed user or group name" do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('testers').returns 'S-1-5-32-547'

      Puppet::Util::Windows::ADSI.sid_for_account('testers').should == 'S-1-5-32-547'
    end

    it "should return a SID for a passed fully-qualified user or group name" do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('MACHINE\testers').returns 'S-1-5-32-547'

      Puppet::Util::Windows::ADSI.sid_for_account('MACHINE\testers').should == 'S-1-5-32-547'
    end
  end

  describe ".computer_name" do
    it "should return a non-empty ComputerName string" do
      Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, nil)
      Puppet::Util::Windows::ADSI.computer_name.should_not be_empty
    end
  end

  describe ".sid_uri" do
    it "should raise an error when the input is not a SID object" do
      [Object.new, {}, 1, :symbol, '', nil].each do |input|
        expect {
          Puppet::Util::Windows::ADSI.sid_uri(input)
        }.to raise_error(Puppet::Error, /Must use a valid SID object/)
      end
    end

    it "should return a SID uri for a well-known SID (SYSTEM)" do
      sid = Win32::Security::SID.new('SYSTEM')
      Puppet::Util::Windows::ADSI.sid_uri(sid).should == 'WinNT://S-1-5-18'
    end
  end

  describe Puppet::Util::Windows::ADSI::User do
    let(:username)  { 'testuser' }
    let(:domain)    { 'DOMAIN' }
    let(:domain_username) { "#{domain}\\#{username}"}

    it "should generate the correct URI" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
      Puppet::Util::Windows::ADSI::User.uri(username).should == "WinNT://./#{username},user"
    end

    it "should generate the correct URI for a user with a domain" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
      Puppet::Util::Windows::ADSI::User.uri(username, domain).should == "WinNT://#{domain}/#{username},user"
    end

    it "should be able to parse a username without a domain" do
      Puppet::Util::Windows::ADSI::User.parse_name(username).should == [username, '.']
    end

    it "should be able to parse a username with a domain" do
      Puppet::Util::Windows::ADSI::User.parse_name(domain_username).should == [username, domain]
    end

    it "should raise an error with a username that contains a /" do
      expect {
        Puppet::Util::Windows::ADSI::User.parse_name("#{domain}/#{username}")
      }.to raise_error(Puppet::Error, /Value must be in DOMAIN\\user style syntax/)
    end

    it "should be able to create a user" do
      adsi_user = stub('adsi')

      connection.expects(:Create).with('user', username).returns(adsi_user)
      Puppet::Util::Windows::ADSI::Group.expects(:exists?).with(username).returns(false)

      user = Puppet::Util::Windows::ADSI::User.create(username)

      user.should be_a(Puppet::Util::Windows::ADSI::User)
      user.native_user.should == adsi_user
    end

    it "should be able to check the existence of a user" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{username},user").returns connection
      Puppet::Util::Windows::ADSI::User.exists?(username).should be_true
    end

    it "should be able to check the existence of a domain user" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://#{domain}/#{username},user").returns connection
      Puppet::Util::Windows::ADSI::User.exists?(domain_username).should be_true
    end

    it "should be able to confirm the existence of a user with a well-known SID" do

      system_user = Win32::Security::SID::LocalSystem
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      Puppet::Util::Windows::ADSI::User.exists?(system_user).should be_true
    end

    it "should return nil with an unknown SID" do

      bogus_sid = 'S-1-2-3-4'
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      Puppet::Util::Windows::ADSI::User.exists?(bogus_sid).should be_false
    end

    it "should be able to delete a user" do
      connection.expects(:Delete).with('user', username)

      Puppet::Util::Windows::ADSI::User.delete(username)
    end

    it "should return an enumeration of IADsUser wrapped objects" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)

      name = 'Administrator'
      wmi_users = [stub('WMI', :name => name)]
      Puppet::Util::Windows::ADSI.expects(:execquery).with('select name from win32_useraccount where localaccount = "TRUE"').returns(wmi_users)

      native_user = stub('IADsUser')
      homedir = "C:\\Users\\#{name}"
      native_user.expects(:Get).with('HomeDirectory').returns(homedir)
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{name},user").returns(native_user)

      users = Puppet::Util::Windows::ADSI::User.to_a
      users.length.should == 1
      users[0].name.should == name
      users[0]['HomeDirectory'].should == homedir
    end

    describe "an instance" do
      let(:adsi_user) { stub('user', :objectSID => []) }
      let(:sid)       { stub(:account => username, :domain => 'testcomputername') }
      let(:user)      { Puppet::Util::Windows::ADSI::User.new(username, adsi_user) }

      it "should provide its groups as a list of names" do
        names = ["group1", "group2"]

        groups = names.map { |name| mock('group', :Name => name) }

        adsi_user.expects(:Groups).returns(groups)

        user.groups.should =~ names
      end

      it "should be able to test whether a given password is correct" do
        Puppet::Util::Windows::ADSI::User.expects(:logon).with(username, 'pwdwrong').returns(false)
        Puppet::Util::Windows::ADSI::User.expects(:logon).with(username, 'pwdright').returns(true)

        user.password_is?('pwdwrong').should be_false
        user.password_is?('pwdright').should be_true
      end

      it "should be able to set a password" do
        adsi_user.expects(:SetPassword).with('pwd')
        adsi_user.expects(:SetInfo).at_least_once

        flagname = "UserFlags"
        fADS_UF_DONT_EXPIRE_PASSWD = 0x10000

        adsi_user.expects(:Get).with(flagname).returns(0)
        adsi_user.expects(:Put).with(flagname, fADS_UF_DONT_EXPIRE_PASSWD)

        user.password = 'pwd'
      end

      it "should generate the correct URI" do
        Puppet::Util::Windows::SID.stubs(:octet_string_to_sid_object).returns(sid)
        user.uri.should == "WinNT://testcomputername/#{username},user"
      end

      describe "when given a set of groups to which to add the user" do
        let(:groups_to_set) { 'group1,group2' }

        before(:each) do
          Puppet::Util::Windows::SID.stubs(:octet_string_to_sid_object).returns(sid)
          user.expects(:groups).returns ['group2', 'group3']
        end

        describe "if membership is specified as inclusive" do
          it "should add the user to those groups, and remove it from groups not in the list" do
            group1 = stub 'group1'
            group1.expects(:Add).with("WinNT://testcomputername/#{username},user")

            group3 = stub 'group1'
            group3.expects(:Remove).with("WinNT://testcomputername/#{username},user")

            Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sid).returns("WinNT://testcomputername/#{username},user").twice
            Puppet::Util::Windows::ADSI.expects(:connect).with('WinNT://./group1,group').returns group1
            Puppet::Util::Windows::ADSI.expects(:connect).with('WinNT://./group3,group').returns group3

            user.set_groups(groups_to_set, false)
          end
        end

        describe "if membership is specified as minimum" do
          it "should add the user to the specified groups without affecting its other memberships" do
            group1 = stub 'group1'
            group1.expects(:Add).with("WinNT://testcomputername/#{username},user")

            Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sid).returns("WinNT://testcomputername/#{username},user")
            Puppet::Util::Windows::ADSI.expects(:connect).with('WinNT://./group1,group').returns group1

            user.set_groups(groups_to_set, true)
          end
        end
      end
    end
  end

  describe Puppet::Util::Windows::ADSI::Group do
    let(:groupname)  { 'testgroup' }

    describe "an instance" do
      let(:adsi_group) { stub 'group' }
      let(:group)      { Puppet::Util::Windows::ADSI::Group.new(groupname, adsi_group) }
      let(:someone_sid){ stub(:account => 'someone', :domain => 'testcomputername')}

      it "should be able to add a member (deprecated)" do
        Puppet.expects(:deprecation_warning).with('Puppet::Util::Windows::ADSI::Group#add_members is deprecated; please use Puppet::Util::Windows::ADSI::Group#add_member_sids')

        Puppet::Util::Windows::SID.expects(:name_to_sid_object).with('someone').returns(someone_sid)
        Puppet::Util::Windows::ADSI.expects(:sid_uri).with(someone_sid).returns("WinNT://testcomputername/someone,user")

        adsi_group.expects(:Add).with("WinNT://testcomputername/someone,user")

        group.add_member('someone')
      end

      it "should raise when adding a member that can't resolve to a SID (deprecated)" do
        expect {
          group.add_member('foobar')
        }.to raise_error(Puppet::Error, /Could not resolve username: foobar/)
      end

      it "should be able to remove a member (deprecated)" do
        Puppet.expects(:deprecation_warning).with('Puppet::Util::Windows::ADSI::Group#remove_members is deprecated; please use Puppet::Util::Windows::ADSI::Group#remove_member_sids')

        Puppet::Util::Windows::SID.expects(:name_to_sid_object).with('someone').returns(someone_sid)
        Puppet::Util::Windows::ADSI.expects(:sid_uri).with(someone_sid).returns("WinNT://testcomputername/someone,user")

        adsi_group.expects(:Remove).with("WinNT://testcomputername/someone,user")

        group.remove_member('someone')
      end

      it "should raise when removing a member that can't resolve to a SID (deprecated)" do
        expect {
          group.remove_member('foobar')
        }.to raise_error(Puppet::Error, /Could not resolve username: foobar/)
      end

      describe "should be able to use SID objects" do
        let(:system)     { Puppet::Util::Windows::SID.name_to_sid_object('SYSTEM') }

        it "to add a member" do
          adsi_group.expects(:Add).with("WinNT://S-1-5-18")

          group.add_member_sids(system)
        end

        it "to remove a member" do
          adsi_group.expects(:Remove).with("WinNT://S-1-5-18")

          group.remove_member_sids(system)
        end
      end

      it "should provide its groups as a list of names" do
        names = ['user1', 'user2']

        users = names.map { |name| mock('user', :Name => name) }

        adsi_group.expects(:Members).returns(users)

        group.members.should =~ names
      end

      it "should be able to add a list of users to a group" do
        names = ['DOMAIN\user1', 'user2']
        sids = [
          stub(:account => 'user1', :domain => 'DOMAIN'),
          stub(:account => 'user2', :domain => 'testcomputername'),
          stub(:account => 'user3', :domain => 'DOMAIN2'),
        ]

        # use stubbed objectSid on member to return stubbed SID
        Puppet::Util::Windows::SID.expects(:octet_string_to_sid_object).with([0]).returns(sids[0])
        Puppet::Util::Windows::SID.expects(:octet_string_to_sid_object).with([1]).returns(sids[1])

        Puppet::Util::Windows::SID.expects(:name_to_sid_object).with('user2').returns(sids[1])
        Puppet::Util::Windows::SID.expects(:name_to_sid_object).with('DOMAIN2\user3').returns(sids[2])

        Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[0]).returns("WinNT://DOMAIN/user1,user")
        Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[2]).returns("WinNT://DOMAIN2/user3,user")

        members = names.each_with_index.map{|n,i| stub(:Name => n, :objectSID => [i])}
        adsi_group.expects(:Members).returns members

        adsi_group.expects(:Remove).with('WinNT://DOMAIN/user1,user')
        adsi_group.expects(:Add).with('WinNT://DOMAIN2/user3,user')

        group.set_members(['user2', 'DOMAIN2\user3'])
      end

      it "should raise an error when a username does not resolve to a SID" do
        expect {
          adsi_group.expects(:Members).returns []
          group.set_members(['foobar'])
        }.to raise_error(Puppet::Error, /Could not resolve username: foobar/)
      end

      it "should generate the correct URI" do
        Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
        group.uri.should == "WinNT://./#{groupname},group"
      end
    end

    it "should generate the correct URI" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
      Puppet::Util::Windows::ADSI::Group.uri("people").should == "WinNT://./people,group"
    end

    it "should be able to create a group" do
      adsi_group = stub("adsi")

      connection.expects(:Create).with('group', groupname).returns(adsi_group)
      Puppet::Util::Windows::ADSI::User.expects(:exists?).with(groupname).returns(false)

      group = Puppet::Util::Windows::ADSI::Group.create(groupname)

      group.should be_a(Puppet::Util::Windows::ADSI::Group)
      group.native_group.should == adsi_group
    end

    it "should be able to confirm the existence of a group" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{groupname},group").returns connection

      Puppet::Util::Windows::ADSI::Group.exists?(groupname).should be_true
    end

    it "should be able to confirm the existence of a group with a well-known SID" do

      service_group = Win32::Security::SID::Service
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      Puppet::Util::Windows::ADSI::Group.exists?(service_group).should be_true
    end

    it "should return nil with an unknown SID" do

      bogus_sid = 'S-1-2-3-4'
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      Puppet::Util::Windows::ADSI::Group.exists?(bogus_sid).should be_false
    end

    it "should be able to delete a group" do
      connection.expects(:Delete).with('group', groupname)

      Puppet::Util::Windows::ADSI::Group.delete(groupname)
    end

    it "should return an enumeration of IADsGroup wrapped objects" do
      Puppet::Util::Windows::ADSI.stubs(:sid_uri_safe).returns(nil)

      name = 'Administrators'
      wmi_groups = [stub('WMI', :name => name)]
      Puppet::Util::Windows::ADSI.expects(:execquery).with('select name from win32_group where localaccount = "TRUE"').returns(wmi_groups)

      native_group = stub('IADsGroup')
      native_group.expects(:Members).returns([stub(:Name => 'Administrator')])
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{name},group").returns(native_group)

      groups = Puppet::Util::Windows::ADSI::Group.to_a
      groups.length.should == 1
      groups[0].name.should == name
      groups[0].members.should == ['Administrator']
    end
  end

  describe Puppet::Util::Windows::ADSI::UserProfile do
    it "should be able to delete a user profile" do
      connection.expects(:Delete).with("Win32_UserProfile.SID='S-A-B-C'")
      Puppet::Util::Windows::ADSI::UserProfile.delete('S-A-B-C')
    end

    it "should warn on 2003" do
      connection.expects(:Delete).raises(RuntimeError,
 "Delete (WIN32OLERuntimeError)
    OLE error code:80041010 in SWbemServicesEx
      Invalid class
    HRESULT error code:0x80020009
      Exception occurred.")

      Puppet.expects(:warning).with("Cannot delete user profile for 'S-A-B-C' prior to Vista SP1")
      Puppet::Util::Windows::ADSI::UserProfile.delete('S-A-B-C')
    end
  end
end
