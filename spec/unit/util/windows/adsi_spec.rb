#!/usr/bin/env ruby

require 'spec_helper'

require 'puppet/util/windows'

describe Puppet::Util::Windows::ADSI, :if => Puppet.features.microsoft_windows? do
  let(:connection) { stub 'connection' }
  let(:builtin_localized) { Puppet::Util::Windows::SID.sid_to_name('S-1-5-32') }
  # SYSTEM is special as English can retrieve it via Windows API
  # but will return localized names
  let(:ntauthority_localized) { Puppet::Util::Windows::SID::Principal.lookup_account_name('SYSTEM').domain }

  before(:each) do
    Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, 'testcomputername')
    Puppet::Util::Windows::ADSI.stubs(:connect).returns connection
  end

  after(:each) do
    Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, nil)
  end

  it "should generate the correct URI for a resource" do
    expect(Puppet::Util::Windows::ADSI.uri('test', 'user')).to eq("WinNT://./test,user")
  end

  it "should be able to get the name of the computer" do
    expect(Puppet::Util::Windows::ADSI.computer_name).to eq('testcomputername')
  end

  it "should be able to provide the correct WinNT base URI for the computer" do
    expect(Puppet::Util::Windows::ADSI.computer_uri).to eq("WinNT://.")
  end

  it "should generate a fully qualified WinNT URI" do
    expect(Puppet::Util::Windows::ADSI.computer_uri('testcomputername')).to eq("WinNT://testcomputername")
  end

  describe ".computer_name" do
    it "should return a non-empty ComputerName string" do
      Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, nil)
      expect(Puppet::Util::Windows::ADSI.computer_name).not_to be_empty
    end
  end

  describe ".sid_uri" do
    it "should raise an error when the input is not a SID Principal" do
      [Object.new, {}, 1, :symbol, '', nil].each do |input|
        expect {
          Puppet::Util::Windows::ADSI.sid_uri(input)
        }.to raise_error(Puppet::Error, /Must use a valid SID::Principal/)
      end
    end

    it "should return a SID uri for a well-known SID (SYSTEM)" do
      sid = Puppet::Util::Windows::SID::Principal.lookup_account_name('SYSTEM')
      expect(Puppet::Util::Windows::ADSI.sid_uri(sid)).to eq('WinNT://S-1-5-18')
    end
  end

  describe Puppet::Util::Windows::ADSI::User do
    let(:username)  { 'testuser' }
    let(:domain)    { 'DOMAIN' }
    let(:domain_username) { "#{domain}\\#{username}"}

    it "should generate the correct URI" do
      expect(Puppet::Util::Windows::ADSI::User.uri(username)).to eq("WinNT://./#{username},user")
    end

    it "should generate the correct URI for a user with a domain" do
      expect(Puppet::Util::Windows::ADSI::User.uri(username, domain)).to eq("WinNT://#{domain}/#{username},user")
    end

    it "should generate the correct URI for a BUILTIN user" do
      expect(Puppet::Util::Windows::ADSI::User.uri(username, builtin_localized)).to eq("WinNT://./#{username},user")
    end

    it "should generate the correct URI for a NT AUTHORITY user" do
      expect(Puppet::Util::Windows::ADSI::User.uri(username, ntauthority_localized)).to eq("WinNT://./#{username},user")
    end

    it "should be able to parse a username without a domain" do
      expect(Puppet::Util::Windows::ADSI::User.parse_name(username)).to eq([username, '.'])
    end

    it "should be able to parse a username with a domain" do
      expect(Puppet::Util::Windows::ADSI::User.parse_name(domain_username)).to eq([username, domain])
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

      expect(user).to be_a(Puppet::Util::Windows::ADSI::User)
      expect(user.native_user).to eq(adsi_user)
    end

    it "should be able to check the existence of a user" do
      Puppet::Util::Windows::SID.expects(:name_to_principal).with(username).returns nil
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{username},user").returns connection
      connection.expects(:Class).returns('User')
      expect(Puppet::Util::Windows::ADSI::User.exists?(username)).to be_truthy
    end

    it "should be able to check the existence of a domain user" do
      Puppet::Util::Windows::SID.expects(:name_to_principal).with("#{domain}\\#{username}").returns nil
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://#{domain}/#{username},user").returns connection
      connection.expects(:Class).returns('User')
      expect(Puppet::Util::Windows::ADSI::User.exists?(domain_username)).to be_truthy
    end

    it "should be able to confirm the existence of a user with a well-known SID" do
      system_user = Puppet::Util::Windows::SID::LocalSystem
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      expect(Puppet::Util::Windows::ADSI::User.exists?(system_user)).to be_truthy
    end

    it "should return false with a well-known Group SID" do
      group = Puppet::Util::Windows::SID::BuiltinAdministrators
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      expect(Puppet::Util::Windows::ADSI::User.exists?(group)).to be_falsey
    end

    it "should return nil with an unknown SID" do

      bogus_sid = 'S-1-2-3-4'
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      expect(Puppet::Util::Windows::ADSI::User.exists?(bogus_sid)).to be_falsey
    end

    it "should be able to delete a user" do
      connection.expects(:Delete).with('user', username)

      Puppet::Util::Windows::ADSI::User.delete(username)
    end

    it "should return an enumeration of IADsUser wrapped objects" do
      name = 'Administrator'
      wmi_users = [stub('WMI', :name => name)]
      Puppet::Util::Windows::ADSI.expects(:execquery).with('select name from win32_useraccount where localaccount = "TRUE"').returns(wmi_users)

      native_user = stub('IADsUser')
      homedir = "C:\\Users\\#{name}"
      native_user.expects(:Get).with('HomeDirectory').returns(homedir)
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{name},user").returns(native_user)

      users = Puppet::Util::Windows::ADSI::User.to_a
      expect(users.length).to eq(1)
      expect(users[0].name).to eq(name)
      expect(users[0]['HomeDirectory']).to eq(homedir)
    end

    describe "an instance" do
      let(:adsi_user) { stub('user', :objectSID => []) }
      let(:sid)       { stub(:account => username, :domain => 'testcomputername') }
      let(:user)      { Puppet::Util::Windows::ADSI::User.new(username, adsi_user) }

      it "should provide its groups as a list of names" do
        names = ["group1", "group2"]

        groups = names.map { |name| stub('group', :Name => name) }

        adsi_user.expects(:Groups).returns(groups)

        expect(user.groups).to match(names)
      end

      it "should be able to test whether a given password is correct" do
        Puppet::Util::Windows::ADSI::User.expects(:logon).with(username, 'pwdwrong').returns(false)
        Puppet::Util::Windows::ADSI::User.expects(:logon).with(username, 'pwdright').returns(true)

        expect(user.password_is?('pwdwrong')).to be_falsey
        expect(user.password_is?('pwdright')).to be_truthy
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

       it "should be able manage a user without a password" do
        adsi_user.expects(:SetPassword).with('pwd').never
        adsi_user.expects(:SetInfo).at_least_once

        flagname = "UserFlags"
        fADS_UF_DONT_EXPIRE_PASSWD = 0x10000

        adsi_user.expects(:Get).with(flagname).returns(0)
        adsi_user.expects(:Put).with(flagname, fADS_UF_DONT_EXPIRE_PASSWD)

        user.password = nil
      end

      it "should generate the correct URI" do
        Puppet::Util::Windows::SID.stubs(:octet_string_to_principal).returns(sid)
        expect(user.uri).to eq("WinNT://testcomputername/#{username},user")
      end

      describe "when given a set of groups to which to add the user" do
        let(:existing_groups) { ['group2','group3'] }
        let(:group_sids) { existing_groups.each_with_index.map{|n,i| stub(:Name => n, :objectSID => stub(:sid => i))} }

        let(:groups_to_set) { 'group1,group2' }
        let(:desired_sids) { groups_to_set.split(',').each_with_index.map{|n,i| stub(:Name => n, :objectSID => stub(:sid => i-1))} }

        before(:each) do
          user.expects(:group_sids).returns(group_sids.map {|s| s.objectSID })
        end

        describe "if membership is specified as inclusive" do
          it "should add the user to those groups, and remove it from groups not in the list" do
            Puppet::Util::Windows::ADSI::User.expects(:name_sid_hash).returns(Hash[ desired_sids.map { |s| [s.objectSID.sid, s.objectSID] }])
            user.expects(:add_group_sids).with { |value| value.sid == -1 }
            user.expects(:remove_group_sids).with { |value| value.sid == 1 }

            user.set_groups(groups_to_set, false)
          end

          it "should remove all users from a group if desired is empty" do
            Puppet::Util::Windows::ADSI::User.expects(:name_sid_hash).returns({})
            user.expects(:add_group_sids).never
            user.expects(:remove_group_sids).with { |user1, user2| user1.sid == 0 && user2.sid == 1 }

            user.set_groups('', false)
          end
        end

        describe "if membership is specified as minimum" do
          it "should add the user to the specified groups without affecting its other memberships" do
            Puppet::Util::Windows::ADSI::User.expects(:name_sid_hash).returns(Hash[ desired_sids.map { |s| [s.objectSID.sid, s.objectSID] }])
            user.expects(:add_group_sids).with { |value| value.sid == -1 }
            user.expects(:remove_group_sids).never

            user.set_groups(groups_to_set, true)
          end

          it "should do nothing if desired is empty" do
            Puppet::Util::Windows::ADSI::User.expects(:name_sid_hash).returns({})
            user.expects(:remove_group_sids).never
            user.expects(:add_group_sids).never

            user.set_groups('', true)
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

      describe "should be able to use SID objects" do
        let(:system)     { Puppet::Util::Windows::SID.name_to_principal('SYSTEM') }
        let(:invalid)    { Puppet::Util::Windows::SID.name_to_principal('foobar') }

        it "to add a member" do
          adsi_group.expects(:Add).with("WinNT://S-1-5-18")

          group.add_member_sids(system)
        end

        it "and raise when passed a non-SID object to add" do
          expect{ group.add_member_sids(invalid)}.to raise_error(Puppet::Error, /Must use a valid SID::Principal/)
        end

        it "to remove a member" do
          adsi_group.expects(:Remove).with("WinNT://S-1-5-18")

          group.remove_member_sids(system)
        end

        it "and raise when passed a non-SID object to remove" do
          expect{ group.remove_member_sids(invalid)}.to raise_error(Puppet::Error, /Must use a valid SID::Principal/)
        end
      end

      it "should provide its groups as a list of names" do
        names = ['user1', 'user2']

        users = names.map { |name| stub('user', :Name => name, :objectSID => name, :ole_respond_to? => true) }

        adsi_group.expects(:Members).returns(users)

        Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with('user1').returns(stub(:domain_account => 'HOSTNAME\user1'))
        Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with('user2').returns(stub(:domain_account => 'HOSTNAME\user2'))

        expect(group.members.map(&:domain_account)).to match(['HOSTNAME\user1', 'HOSTNAME\user2'])
      end

      context "calling .set_members" do
        it "should set the members of a group to only desired_members when inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
              stub(:account => 'user1', :domain => 'DOMAIN', :sid => 1),
              stub(:account => 'user2', :domain => 'testcomputername', :sid => 2),
              stub(:account => 'user3', :domain => 'DOMAIN2', :sid => 3),
          ]

          # use stubbed objectSid on member to return stubbed SID
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([0]).returns(sids[0])
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([1]).returns(sids[1])

          Puppet::Util::Windows::SID.expects(:name_to_principal).with('user2').returns(sids[1])
          Puppet::Util::Windows::SID.expects(:name_to_principal).with('DOMAIN2\user3').returns(sids[2])

          Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[0]).returns("WinNT://DOMAIN/user1,user")
          Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[2]).returns("WinNT://DOMAIN2/user3,user")

          members = names.each_with_index.map{|n,i| stub(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          adsi_group.expects(:Members).returns members

          adsi_group.expects(:Remove).with('WinNT://DOMAIN/user1,user')
          adsi_group.expects(:Add).with('WinNT://DOMAIN2/user3,user')

          group.set_members(['user2', 'DOMAIN2\user3'])
        end

        it "should add the desired_members to an existing group when not inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
              stub(:account => 'user1', :domain => 'DOMAIN', :sid => 1),
              stub(:account => 'user2', :domain => 'testcomputername', :sid => 2),
              stub(:account => 'user3', :domain => 'DOMAIN2', :sid => 3),
          ]

          # use stubbed objectSid on member to return stubbed SID
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([0]).returns(sids[0])
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([1]).returns(sids[1])

          Puppet::Util::Windows::SID.expects(:name_to_principal).with('user2').returns(sids[1])
          Puppet::Util::Windows::SID.expects(:name_to_principal).with('DOMAIN2\user3').returns(sids[2])

          Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[2]).returns("WinNT://DOMAIN2/user3,user")

          members = names.each_with_index.map{|n,i| stub(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          adsi_group.expects(:Members).returns members

          adsi_group.expects(:Remove).with('WinNT://DOMAIN/user1,user').never

          adsi_group.expects(:Add).with('WinNT://DOMAIN2/user3,user')

          group.set_members(['user2', 'DOMAIN2\user3'],false)
        end

        it "should return immediately when desired_members is nil" do
          adsi_group.expects(:Members).never

          adsi_group.expects(:Remove).never
          adsi_group.expects(:Add).never

          group.set_members(nil)
        end

        it "should remove all members when desired_members is empty and inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
              stub(:account => 'user1', :domain => 'DOMAIN', :sid => 1 ),
              stub(:account => 'user2', :domain => 'testcomputername', :sid => 2 ),
          ]

          # use stubbed objectSid on member to return stubbed SID
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([0]).returns(sids[0])
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([1]).returns(sids[1])

          Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[0]).returns("WinNT://DOMAIN/user1,user")
          Puppet::Util::Windows::ADSI.expects(:sid_uri).with(sids[1]).returns("WinNT://testcomputername/user2,user")

          members = names.each_with_index.map{|n,i| stub(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          adsi_group.expects(:Members).returns members

          adsi_group.expects(:Remove).with('WinNT://DOMAIN/user1,user')
          adsi_group.expects(:Remove).with('WinNT://testcomputername/user2,user')

          group.set_members([])
        end

        it "should do nothing when desired_members is empty and not inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
              stub(:account => 'user1', :domain => 'DOMAIN', :sid => 1 ),
              stub(:account => 'user2', :domain => 'testcomputername', :sid => 2 ),
          ]
          # use stubbed objectSid on member to return stubbed SID
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([0]).returns(sids[0])
          Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([1]).returns(sids[1])

          members = names.each_with_index.map{|n,i| stub(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          adsi_group.expects(:Members).returns members

          adsi_group.expects(:Remove).never
          adsi_group.expects(:Add).never

          group.set_members([],false)
        end

        it "should raise an error when a username does not resolve to a SID" do
          expect {
            adsi_group.expects(:Members).returns []
            group.set_members(['foobar'])
          }.to raise_error(Puppet::Error, /Could not resolve name: foobar/)
        end
      end

      it "should generate the correct URI" do
        adsi_group.expects(:objectSID).returns([0])
        Socket.expects(:gethostname).returns('TESTcomputerNAME')
        computer_sid = stub(:account => groupname,:domain => 'testcomputername')
        Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([0]).returns(computer_sid)
        expect(group.uri).to eq("WinNT://./#{groupname},group")
      end
    end

    it "should generate the correct URI" do
      expect(Puppet::Util::Windows::ADSI::Group.uri("people")).to eq("WinNT://./people,group")
    end

    it "should generate the correct URI for a BUILTIN group" do
      expect(Puppet::Util::Windows::ADSI::Group.uri(groupname, builtin_localized)).to eq("WinNT://./#{groupname},group")
    end

    it "should generate the correct URI for a NT AUTHORITY group" do
      expect(Puppet::Util::Windows::ADSI::Group.uri(groupname, ntauthority_localized)).to eq("WinNT://./#{groupname},group")
    end

    it "should be able to create a group" do
      adsi_group = stub("adsi")

      connection.expects(:Create).with('group', groupname).returns(adsi_group)
      Puppet::Util::Windows::ADSI::User.expects(:exists?).with(groupname).returns(false)

      group = Puppet::Util::Windows::ADSI::Group.create(groupname)

      expect(group).to be_a(Puppet::Util::Windows::ADSI::Group)
      expect(group.native_group).to eq(adsi_group)
    end

    it "should be able to confirm the existence of a group" do
      Puppet::Util::Windows::SID.expects(:name_to_principal).with(groupname).returns nil
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{groupname},group").returns connection
      connection.expects(:Class).returns('Group')

      expect(Puppet::Util::Windows::ADSI::Group.exists?(groupname)).to be_truthy
    end

    it "should be able to confirm the existence of a group with a well-known SID" do

      service_group = Puppet::Util::Windows::SID::Service
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      expect(Puppet::Util::Windows::ADSI::Group.exists?(service_group)).to be_truthy
    end

    it "will return true with a well-known User SID, as there is no way to resolve it with a WinNT:// style moniker" do
      user = Puppet::Util::Windows::SID::NtLocal
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      expect(Puppet::Util::Windows::ADSI::Group.exists?(user)).to be_truthy
    end

    it "should return nil with an unknown SID" do

      bogus_sid = 'S-1-2-3-4'
      # ensure that the underlying OS is queried here
      Puppet::Util::Windows::ADSI.unstub(:connect)
      expect(Puppet::Util::Windows::ADSI::Group.exists?(bogus_sid)).to be_falsey
    end

    it "should be able to delete a group" do
      connection.expects(:Delete).with('group', groupname)

      Puppet::Util::Windows::ADSI::Group.delete(groupname)
    end

    it "should return an enumeration of IADsGroup wrapped objects" do
      name = 'Administrators'
      wmi_groups = [stub('WMI', :name => name)]
      Puppet::Util::Windows::ADSI.expects(:execquery).with('select name from win32_group where localaccount = "TRUE"').returns(wmi_groups)

      native_group = stub('IADsGroup')
      Puppet::Util::Windows::SID.expects(:octet_string_to_principal).with([]).returns(stub(:domain_account => '.\Administrator'))
      native_group.expects(:Members).returns([stub(:Name => 'Administrator', :objectSID => [], :ole_respond_to? => true)])
      Puppet::Util::Windows::ADSI.expects(:connect).with("WinNT://./#{name},group").returns(native_group)

      groups = Puppet::Util::Windows::ADSI::Group.to_a
      expect(groups.length).to eq(1)
      expect(groups[0].name).to eq(name)
      expect(groups[0].members.map(&:domain_account)).to eq(['.\Administrator'])
    end
  end

  describe Puppet::Util::Windows::ADSI::UserProfile do
    it "should be able to delete a user profile" do
      connection.expects(:Delete).with("Win32_UserProfile.SID='S-A-B-C'")
      Puppet::Util::Windows::ADSI::UserProfile.delete('S-A-B-C')
    end

    it "should warn on 2003" do
      connection.expects(:Delete).raises(WIN32OLERuntimeError,
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
