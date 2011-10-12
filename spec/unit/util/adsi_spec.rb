#!/usr/bin/env ruby

require 'spec_helper'

require 'puppet/util/adsi'

describe Puppet::Util::ADSI do
  let(:connection) { stub 'connection' }

  before(:each) do
    Puppet::Util::ADSI.instance_variable_set(:@computer_name, 'testcomputername')
    Puppet::Util::ADSI.stubs(:connect).returns connection
  end

  after(:each) do
    Puppet::Util::ADSI.instance_variable_set(:@computer_name, nil)
  end

  it "should generate the correct URI for a resource" do
    Puppet::Util::ADSI.uri('test', 'user').should == "WinNT://testcomputername/test,user"
  end

  it "should be able to get the name of the computer" do
    Puppet::Util::ADSI.computer_name.should == 'testcomputername'
  end

  it "should be able to provide the correct WinNT base URI for the computer" do
    Puppet::Util::ADSI.computer_uri.should == "WinNT://testcomputername"
  end

  describe ".sid_for_account" do
    it "should return nil if the account does not exist" do
      connection.expects(:execquery).returns([])

      Puppet::Util::ADSI.sid_for_account('foobar').should be_nil
    end

    it "should return a SID for a passed user or group name" do
      Puppet::Util::ADSI.expects(:execquery).with(
        "SELECT Sid from Win32_Account WHERE Name = 'testers' AND LocalAccount = true"
      ).returns([stub('acct_id', :Sid => 'S-1-5-32-547')])

      Puppet::Util::ADSI.sid_for_account('testers').should == 'S-1-5-32-547'
    end

    it "should return a SID for a passed fully-qualified user or group name" do
      Puppet::Util::ADSI.expects(:execquery).with(
        "SELECT Sid from Win32_Account WHERE Name = 'testers' AND Domain = 'MACHINE' AND LocalAccount = true"
      ).returns([stub('acct_id', :Sid => 'S-1-5-32-547')])

      Puppet::Util::ADSI.sid_for_account('MACHINE\testers').should == 'S-1-5-32-547'
    end
  end

  describe Puppet::Util::ADSI::User do
    let(:username)  { 'testuser' }

    it "should generate the correct URI" do
      Puppet::Util::ADSI::User.uri(username).should == "WinNT://testcomputername/#{username},user"
    end

    it "should be able to create a user" do
      adsi_user = stub('adsi')

      connection.expects(:Create).with('user', username).returns(adsi_user)
      Puppet::Util::ADSI::Group.expects(:exists?).with(username).returns(false)

      user = Puppet::Util::ADSI::User.create(username)

      user.should be_a(Puppet::Util::ADSI::User)
      user.native_user.should == adsi_user
    end

    it "should be able to check the existence of a user" do
      Puppet::Util::ADSI.expects(:connect).with("WinNT://testcomputername/#{username},user").returns connection
      Puppet::Util::ADSI::User.exists?(username).should be_true
    end

    it "should be able to delete a user" do
      connection.expects(:Delete).with('user', username)

      Puppet::Util::ADSI::User.delete(username)
    end

    describe "an instance" do
      let(:adsi_user) { stub 'user' }
      let(:user)      { Puppet::Util::ADSI::User.new(username, adsi_user) }

      it "should provide its groups as a list of names" do
        names = ["group1", "group2"]

        groups = names.map { |name| mock('group', :Name => name) }

        adsi_user.expects(:Groups).returns(groups)

        user.groups.should =~ names
      end

      it "should be able to test whether a given password is correct" do
        Puppet::Util::ADSI::User.expects(:logon).with(username, 'pwdwrong').returns(false)
        Puppet::Util::ADSI::User.expects(:logon).with(username, 'pwdright').returns(true)

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
        user.uri.should == "WinNT://testcomputername/#{username},user"
      end

      describe "when given a set of groups to which to add the user" do
        let(:groups_to_set) { 'group1,group2' }

        before(:each) do
          user.expects(:groups).returns ['group2', 'group3']
        end

        describe "if membership is specified as inclusive" do
          it "should add the user to those groups, and remove it from groups not in the list" do
            group1 = stub 'group1'
            group1.expects(:Add).with("WinNT://testcomputername/#{username},user")

            group3 = stub 'group1'
            group3.expects(:Remove).with("WinNT://testcomputername/#{username},user")

            Puppet::Util::ADSI.expects(:connect).with('WinNT://testcomputername/group1,group').returns group1
            Puppet::Util::ADSI.expects(:connect).with('WinNT://testcomputername/group3,group').returns group3

            user.set_groups(groups_to_set, false)
          end
        end

        describe "if membership is specified as minimum" do
          it "should add the user to the specified groups without affecting its other memberships" do
            group1 = stub 'group1'
            group1.expects(:Add).with("WinNT://testcomputername/#{username},user")

            Puppet::Util::ADSI.expects(:connect).with('WinNT://testcomputername/group1,group').returns group1

            user.set_groups(groups_to_set, true)
          end
        end
      end
    end
  end

  describe Puppet::Util::ADSI::Group do
    let(:groupname)  { 'testgroup' }

    describe "an instance" do
      let(:adsi_group) { stub 'group' }
      let(:group)      { Puppet::Util::ADSI::Group.new(groupname, adsi_group) }

      it "should be able to add a member" do
        adsi_group.expects(:Add).with("WinNT://testcomputername/someone,user")

        group.add_member('someone')
      end

      it "should be able to remove a member" do
        adsi_group.expects(:Remove).with("WinNT://testcomputername/someone,user")

        group.remove_member('someone')
      end

      it "should provide its groups as a list of names" do
        names = ['user1', 'user2']

        users = names.map { |name| mock('user', :Name => name) }

        adsi_group.expects(:Members).returns(users)

        group.members.should =~ names
      end

      it "should be able to add a list of users to a group" do
        names = ['user1', 'user2']
        adsi_group.expects(:Members).returns names.map{|n| stub(:Name => n)}

        adsi_group.expects(:Remove).with('WinNT://testcomputername/user1,user')
        adsi_group.expects(:Add).with('WinNT://testcomputername/user3,user')

        group.set_members(['user2', 'user3'])
      end

      it "should generate the correct URI" do
        group.uri.should == "WinNT://testcomputername/#{groupname},group"
      end
    end

    it "should generate the correct URI" do
      Puppet::Util::ADSI::Group.uri("people").should == "WinNT://testcomputername/people,group"
    end

    it "should be able to create a group" do
      adsi_group = stub("adsi")

      connection.expects(:Create).with('group', groupname).returns(adsi_group)
      Puppet::Util::ADSI::User.expects(:exists?).with(groupname).returns(false)

      group = Puppet::Util::ADSI::Group.create(groupname)

      group.should be_a(Puppet::Util::ADSI::Group)
      group.native_group.should == adsi_group
    end

    it "should be able to confirm the existence of a group" do
      Puppet::Util::ADSI.expects(:connect).with("WinNT://testcomputername/#{groupname},group").returns connection

      Puppet::Util::ADSI::Group.exists?(groupname).should be_true
    end

    it "should be able to delete a group" do
      connection.expects(:Delete).with('group', groupname)

      Puppet::Util::ADSI::Group.delete(groupname)
    end
  end
end
