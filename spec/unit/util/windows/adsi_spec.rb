require 'spec_helper'

require 'puppet/util/windows'

describe Puppet::Util::Windows::ADSI, :if => Puppet.features.microsoft_windows? do
  let(:connection) { double('connection') }
  let(:builtin_localized) { Puppet::Util::Windows::SID.sid_to_name('S-1-5-32') }
  # SYSTEM is special as English can retrieve it via Windows API
  # but will return localized names
  let(:ntauthority_localized) { Puppet::Util::Windows::SID::Principal.lookup_account_name('SYSTEM').domain }

  before(:each) do
    Puppet::Util::Windows::ADSI.instance_variable_set(:@computer_name, 'testcomputername')
    allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_return(connection)
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

  describe ".domain_role" do
    DOMAIN_ROLES = Puppet::Util::Platform.windows? ? Puppet::Util::Windows::ADSI::DOMAIN_ROLES : {}

    DOMAIN_ROLES.each do |id, role|
      it "should be able to return #{role} as the domain role of the computer" do
        Puppet::Util::Windows::ADSI.instance_variable_set(:@domain_role, nil)
        domain_role = [double('WMI', :DomainRole => id)]
        allow(Puppet::Util::Windows::ADSI).to receive(:execquery).with('select DomainRole from Win32_ComputerSystem').and_return(domain_role)
        expect(Puppet::Util::Windows::ADSI.domain_role).to eq(role)
      end
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

  shared_examples 'a local only resource query' do |klass, account_type|
    before(:each) do
      allow(Puppet::Util::Windows::ADSI).to receive(:domain_role).and_return(:MEMBER_SERVER)
    end

    it "should be able to check for a local resource" do
      local_domain = 'testcomputername'
      principal = double('Principal', :account => resource_name, :domain => local_domain, :account_type => account_type)
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).with(resource_name).and_return(principal)
      expect(klass.exists?(resource_name)).to eq(true)
    end

    it "should be case insensitive when comparing the domain with the computer name" do
      local_domain = 'TESTCOMPUTERNAME'
      principal = double('Principal', :account => resource_name, :domain => local_domain, :account_type => account_type)
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).with(resource_name).and_return(principal)
      expect(klass.exists?(resource_name)).to eq(true)
    end

    it "should return false if no local resource exists" do
      principal = double('Principal', :account => resource_name, :domain => 'AD_DOMAIN', :account_type => account_type)
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).with(resource_name).and_return(principal)
      expect(klass.exists?(resource_name)).to eq(false)
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
      adsi_user = double('adsi')

      expect(connection).to receive(:Create).with('user', username).and_return(adsi_user)
      expect(Puppet::Util::Windows::ADSI::Group).to receive(:exists?).with(username).and_return(false)

      user = Puppet::Util::Windows::ADSI::User.create(username)

      expect(user).to be_a(Puppet::Util::Windows::ADSI::User)
      expect(user.native_object).to eq(adsi_user)
    end

    context "when domain-joined" do
      it_should_behave_like 'a local only resource query', Puppet::Util::Windows::ADSI::User, :SidTypeUser do
        let(:resource_name) { username }
      end
    end

    it "should be able to check the existence of a user" do
      expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with(username).and_return(nil)
      expect(Puppet::Util::Windows::ADSI).to receive(:connect).with("WinNT://./#{username},user").and_return(connection)
      expect(connection).to receive(:Class).and_return('User')
      expect(Puppet::Util::Windows::ADSI::User.exists?(username)).to be_truthy
    end

    it "should be able to check the existence of a domain user" do
      expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with("#{domain}\\#{username}").and_return(nil)
      expect(Puppet::Util::Windows::ADSI).to receive(:connect).with("WinNT://#{domain}/#{username},user").and_return(connection)
      expect(connection).to receive(:Class).and_return('User')
      expect(Puppet::Util::Windows::ADSI::User.exists?(domain_username)).to be_truthy
    end

    it "should be able to confirm the existence of a user with a well-known SID" do
      system_user = Puppet::Util::Windows::SID::LocalSystem
      # ensure that the underlying OS is queried here
      allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_call_original()
      expect(Puppet::Util::Windows::ADSI::User.exists?(system_user)).to be_truthy
    end

    it "should return false with a well-known Group SID" do
      group = Puppet::Util::Windows::SID::BuiltinAdministrators
      # ensure that the underlying OS is queried here
      allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_call_original()
      expect(Puppet::Util::Windows::ADSI::User.exists?(group)).to be_falsey
    end

    it "should return nil with an unknown SID" do
      bogus_sid = 'S-1-2-3-4'
      # ensure that the underlying OS is queried here
      allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_call_original()
      expect(Puppet::Util::Windows::ADSI::User.exists?(bogus_sid)).to be_falsey
    end

    it "should be able to delete a user" do
      expect(connection).to receive(:Delete).with('user', username)

      Puppet::Util::Windows::ADSI::User.delete(username)
    end

    it "should return an enumeration of IADsUser wrapped objects" do
      name = 'Administrator'
      wmi_users = [double('WMI', :name => name)]
      expect(Puppet::Util::Windows::ADSI).to receive(:execquery).with('select name from win32_useraccount where localaccount = "TRUE"').and_return(wmi_users)

      native_object = double('IADsUser')
      homedir = "C:\\Users\\#{name}"
      expect(native_object).to receive(:Get).with('HomeDirectory').and_return(homedir)
      expect(Puppet::Util::Windows::ADSI).to receive(:connect).with("WinNT://./#{name},user").and_return(native_object)

      users = Puppet::Util::Windows::ADSI::User.to_a
      expect(users.length).to eq(1)
      expect(users[0].name).to eq(name)
      expect(users[0]['HomeDirectory']).to eq(homedir)
    end

    describe "an instance" do
      let(:adsi_user) { double('user', :objectSID => []) }
      let(:sid)       { double(:account => username, :domain => 'testcomputername') }
      let(:user)      { Puppet::Util::Windows::ADSI::User.new(username, adsi_user) }

      it "should provide its groups as a list of names" do
        names = ["group1", "group2"]

        groups = names.map { |name| double('group', :Name => name) }

        expect(adsi_user).to receive(:Groups).and_return(groups)

        expect(user.groups).to match(names)
      end

      it "should be able to test whether a given password is correct" do
        expect(Puppet::Util::Windows::ADSI::User).to receive(:logon).with(username, 'pwdwrong').and_return(false)
        expect(Puppet::Util::Windows::ADSI::User).to receive(:logon).with(username, 'pwdright').and_return(true)

        expect(user.password_is?('pwdwrong')).to be_falsey
        expect(user.password_is?('pwdright')).to be_truthy
      end

      it "should be able to set a password" do
        expect(adsi_user).to receive(:SetPassword).with('pwd')
        expect(adsi_user).to receive(:SetInfo).at_least(:once)

        flagname = "UserFlags"
        fADS_UF_DONT_EXPIRE_PASSWD = 0x10000

        expect(adsi_user).to receive(:Get).with(flagname).and_return(0)
        expect(adsi_user).to receive(:Put).with(flagname, fADS_UF_DONT_EXPIRE_PASSWD)

        user.password = 'pwd'
      end

       it "should be able manage a user without a password" do
        expect(adsi_user).not_to receive(:SetPassword).with('pwd')
        expect(adsi_user).to receive(:SetInfo).at_least(:once)

        flagname = "UserFlags"
        fADS_UF_DONT_EXPIRE_PASSWD = 0x10000

        expect(adsi_user).to receive(:Get).with(flagname).and_return(0)
        expect(adsi_user).to receive(:Put).with(flagname, fADS_UF_DONT_EXPIRE_PASSWD)

        user.password = nil
      end

      it "should generate the correct URI" do
        allow(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).and_return(sid)
        expect(user.uri).to eq("WinNT://testcomputername/#{username},user")
      end

      describe "when given a set of groups to which to add the user" do
        let(:existing_groups) { ['group2','group3'] }
        let(:group_sids) { existing_groups.each_with_index.map{|n,i| double(:Name => n, :objectSID => double(:sid => i))} }

        let(:groups_to_set) { 'group1,group2' }
        let(:desired_sids) { groups_to_set.split(',').each_with_index.map{|n,i| double(:Name => n, :objectSID => double(:sid => i-1))} }

        before(:each) do
          expect(user).to receive(:group_sids).and_return(group_sids.map {|s| s.objectSID })
        end

        describe "if membership is specified as inclusive" do
          it "should add the user to those groups, and remove it from groups not in the list" do
            expect(Puppet::Util::Windows::ADSI::User).to receive(:name_sid_hash).and_return(Hash[ desired_sids.map { |s| [s.objectSID.sid, s.objectSID] }])
            expect(user).to receive(:add_group_sids) { |value| expect(value.sid).to eq(-1) }
            expect(user).to receive(:remove_group_sids) { |value| expect(value.sid).to eq(1) }

            user.set_groups(groups_to_set, false)
          end

          it "should remove all users from a group if desired is empty" do
            expect(Puppet::Util::Windows::ADSI::User).to receive(:name_sid_hash).and_return({})
            expect(user).not_to receive(:add_group_sids)
            expect(user).to receive(:remove_group_sids) do |user1, user2|
              expect(user1.sid).to eq(0)
              expect(user2.sid).to eq(1)
            end

            user.set_groups('', false)
          end
        end

        describe "if membership is specified as minimum" do
          it "should add the user to the specified groups without affecting its other memberships" do
            expect(Puppet::Util::Windows::ADSI::User).to receive(:name_sid_hash).and_return(Hash[ desired_sids.map { |s| [s.objectSID.sid, s.objectSID] }])
            expect(user).to receive(:add_group_sids) { |value| expect(value.sid).to eq(-1) }
            expect(user).not_to receive(:remove_group_sids)

            user.set_groups(groups_to_set, true)
          end

          it "should do nothing if desired is empty" do
            expect(Puppet::Util::Windows::ADSI::User).to receive(:name_sid_hash).and_return({})
            expect(user).not_to receive(:remove_group_sids)
            expect(user).not_to receive(:add_group_sids)

            user.set_groups('', true)
          end
        end
      end

      describe 'userflags' do
        # Avoid having to type out the constant everytime we want to
        # retrieve a userflag's value.
        def ads_userflags(flag)
          Puppet::Util::Windows::ADSI::User::ADS_USERFLAGS[flag]
        end

        before(:each) do
          userflags = [
            :ADS_UF_SCRIPT,
            :ADS_UF_ACCOUNTDISABLE,
            :ADS_UF_HOMEDIR_REQUIRED,
            :ADS_UF_LOCKOUT
          ].inject(0) do |flags, flag|
            flags | ads_userflags(flag)
          end

          allow(user).to receive(:[]).with('UserFlags').and_return(userflags)
        end

        describe '#userflag_set?' do
          it 'returns true if the specified userflag is set' do
            expect(user.userflag_set?(:ADS_UF_SCRIPT)).to be true
          end

          it 'returns false if the specified userflag is not set' do
            expect(user.userflag_set?(:ADS_UF_PASSWD_NOTREQD)).to be false
          end

          it 'returns false if the specified userflag is an unrecognized userflag' do
            expect(user.userflag_set?(:ADS_UF_UNRECOGNIZED_FLAG)).to be false
          end
        end

        shared_examples 'set/unset common tests' do |method|
          it 'raises an ArgumentError for any unrecognized userflags' do
            unrecognized_flags = [
              :ADS_UF_UNRECOGNIZED_FLAG_ONE,
              :ADS_UF_UNRECOGNIZED_FLAG_TWO
            ]
            input_flags = unrecognized_flags + [
              :ADS_UF_PASSWORD_EXPIRED,
              :ADS_UF_DONT_EXPIRE_PASSWD
            ]

            expect { user.send(method, *input_flags) }.to raise_error(
              ArgumentError, /#{unrecognized_flags.join(', ')}/
            )
          end

          it 'noops if no userflags are passed-in' do
            expect(user).not_to receive(:[]=)
            expect(user).not_to receive(:commit)

            user.send(method)
          end
        end

        describe '#set_userflags' do
          include_examples 'set/unset common tests', :set_userflags

          it 'should add the passed-in flags to the current set of userflags' do
            input_flags = [
              :ADS_UF_PASSWORD_EXPIRED,
              :ADS_UF_DONT_EXPIRE_PASSWD
            ]

            userflags = user['UserFlags']
            expected_userflags = userflags | ads_userflags(input_flags[0]) | ads_userflags(input_flags[1])

            expect(user).to receive(:[]=).with('UserFlags', expected_userflags)

            user.set_userflags(*input_flags)
          end
        end

        describe '#unset_userflags' do
          include_examples 'set/unset common tests', :unset_userflags

          it 'should remove the passed-in flags from the current set of userflags' do
            input_flags = [
              :ADS_UF_SCRIPT,
              :ADS_UF_ACCOUNTDISABLE
            ]

            # ADS_UF_HOMEDIR_REQUIRED and ADS_UF_LOCKOUT should be the only flags set.
            expected_userflags = 0 | ads_userflags(:ADS_UF_HOMEDIR_REQUIRED) | ads_userflags(:ADS_UF_LOCKOUT)

            expect(user).to receive(:[]=).with('UserFlags', expected_userflags)

            user.unset_userflags(*input_flags)
          end
        end
      end
    end
  end

  describe Puppet::Util::Windows::ADSI::Group do
    let(:groupname)  { 'testgroup' }

    describe "an instance" do
      let(:adsi_group) { double('group') }
      let(:group)      { Puppet::Util::Windows::ADSI::Group.new(groupname, adsi_group) }
      let(:someone_sid){ double(:account => 'someone', :domain => 'testcomputername')}

      describe "should be able to use SID objects" do
        let(:system)     { Puppet::Util::Windows::SID.name_to_principal('SYSTEM') }
        let(:invalid)    { Puppet::Util::Windows::SID.name_to_principal('foobar') }

        it "to add a member" do
          expect(adsi_group).to receive(:Add).with("WinNT://S-1-5-18")

          group.add_member_sids(system)
        end

        it "and raise when passed a non-SID object to add" do
          expect{ group.add_member_sids(invalid)}.to raise_error(Puppet::Error, /Must use a valid SID::Principal/)
        end

        it "to remove a member" do
          expect(adsi_group).to receive(:Remove).with("WinNT://S-1-5-18")

          group.remove_member_sids(system)
        end

        it "and raise when passed a non-SID object to remove" do
          expect{ group.remove_member_sids(invalid)}.to raise_error(Puppet::Error, /Must use a valid SID::Principal/)
        end
      end

      it "should provide its groups as a list of names" do
        names = ['user1', 'user2']

        users = names.map { |name| double('user', :Name => name, :objectSID => name, :ole_respond_to? => true) }

        expect(adsi_group).to receive(:Members).and_return(users)

        expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with('user1').and_return(double(:domain_account => 'HOSTNAME\user1'))
        expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with('user2').and_return(double(:domain_account => 'HOSTNAME\user2'))

        expect(group.members.map(&:domain_account)).to match(['HOSTNAME\user1', 'HOSTNAME\user2'])
      end

      context "calling .set_members" do
        it "should set the members of a group to only desired_members when inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
            double(:account => 'user1', :domain => 'DOMAIN', :sid => 1),
            double(:account => 'user2', :domain => 'testcomputername', :sid => 2),
            double(:account => 'user3', :domain => 'DOMAIN2', :sid => 3),
          ]

          # use stubbed objectSid on member to return stubbed SID
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([0]).and_return(sids[0])
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([1]).and_return(sids[1])

          expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('user2', false).and_return(sids[1])
          expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('DOMAIN2\user3', false).and_return(sids[2])

          expect(Puppet::Util::Windows::ADSI).to receive(:sid_uri).with(sids[0]).and_return("WinNT://DOMAIN/user1,user")
          expect(Puppet::Util::Windows::ADSI).to receive(:sid_uri).with(sids[2]).and_return("WinNT://DOMAIN2/user3,user")

          members = names.each_with_index.map{|n,i| double(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          expect(adsi_group).to receive(:Members).and_return(members)

          expect(adsi_group).to receive(:Remove).with('WinNT://DOMAIN/user1,user')
          expect(adsi_group).to receive(:Add).with('WinNT://DOMAIN2/user3,user')

          group.set_members(['user2', 'DOMAIN2\user3'])
        end

        it "should add the desired_members to an existing group when not inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
            double(:account => 'user1', :domain => 'DOMAIN', :sid => 1),
            double(:account => 'user2', :domain => 'testcomputername', :sid => 2),
            double(:account => 'user3', :domain => 'DOMAIN2', :sid => 3),
          ]

          # use stubbed objectSid on member to return stubbed SID
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([0]).and_return(sids[0])
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([1]).and_return(sids[1])

          expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('user2', any_args).and_return(sids[1])
          expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('DOMAIN2\user3', any_args).and_return(sids[2])

          expect(Puppet::Util::Windows::ADSI).to receive(:sid_uri).with(sids[2]).and_return("WinNT://DOMAIN2/user3,user")

          members = names.each_with_index.map {|n,i| double(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          expect(adsi_group).to receive(:Members).and_return(members)

          expect(adsi_group).not_to receive(:Remove).with('WinNT://DOMAIN/user1,user')

          expect(adsi_group).to receive(:Add).with('WinNT://DOMAIN2/user3,user')

          group.set_members(['user2', 'DOMAIN2\user3'],false)
        end

        it "should return immediately when desired_members is nil" do
          expect(adsi_group).not_to receive(:Members)

          expect(adsi_group).not_to receive(:Remove)
          expect(adsi_group).not_to receive(:Add)

          group.set_members(nil)
        end

        it "should remove all members when desired_members is empty and inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
            double(:account => 'user1', :domain => 'DOMAIN', :sid => 1 ),
            double(:account => 'user2', :domain => 'testcomputername', :sid => 2 ),
          ]

          # use stubbed objectSid on member to return stubbed SID
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([0]).and_return(sids[0])
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([1]).and_return(sids[1])

          expect(Puppet::Util::Windows::ADSI).to receive(:sid_uri).with(sids[0]).and_return("WinNT://DOMAIN/user1,user")
          expect(Puppet::Util::Windows::ADSI).to receive(:sid_uri).with(sids[1]).and_return("WinNT://testcomputername/user2,user")

          members = names.each_with_index.map{|n,i| double(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          expect(adsi_group).to receive(:Members).and_return(members)

          expect(adsi_group).to receive(:Remove).with('WinNT://DOMAIN/user1,user')
          expect(adsi_group).to receive(:Remove).with('WinNT://testcomputername/user2,user')

          group.set_members([])
        end

        it "should do nothing when desired_members is empty and not inclusive" do
          names = ['DOMAIN\user1', 'user2']
          sids = [
            double(:account => 'user1', :domain => 'DOMAIN', :sid => 1 ),
            double(:account => 'user2', :domain => 'testcomputername', :sid => 2 ),
          ]
          # use stubbed objectSid on member to return stubbed SID
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([0]).and_return(sids[0])
          expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([1]).and_return(sids[1])

          members = names.each_with_index.map{|n,i| double(:Name => n, :objectSID => [i], :ole_respond_to? => true)}
          expect(adsi_group).to receive(:Members).and_return(members)

          expect(adsi_group).not_to receive(:Remove)
          expect(adsi_group).not_to receive(:Add)

          group.set_members([],false)
        end

        it "should raise an error when a username does not resolve to a SID" do
          expect {
            expect(adsi_group).to receive(:Members).and_return([])
            group.set_members(['foobar'])
          }.to raise_error(Puppet::Error, /Could not resolve name: foobar/)
        end
      end

      it "should generate the correct URI" do
        expect(adsi_group).to receive(:objectSID).and_return([0])
        expect(Socket).to receive(:gethostname).and_return('TESTcomputerNAME')
        computer_sid = double(:account => groupname,:domain => 'testcomputername')
        expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([0]).and_return(computer_sid)
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

    context "when domain-joined" do
      it_should_behave_like 'a local only resource query', Puppet::Util::Windows::ADSI::Group, :SidTypeGroup do
        let(:resource_name) { groupname }
      end
    end

    it "should be able to create a group" do
      adsi_group = double("adsi")

      expect(connection).to receive(:Create).with('group', groupname).and_return(adsi_group)
      expect(Puppet::Util::Windows::ADSI::User).to receive(:exists?).with(groupname).and_return(false)

      group = Puppet::Util::Windows::ADSI::Group.create(groupname)

      expect(group).to be_a(Puppet::Util::Windows::ADSI::Group)
      expect(group.native_object).to eq(adsi_group)
    end

    it "should be able to confirm the existence of a group" do
      expect(Puppet::Util::Windows::SID).to receive(:name_to_principal).with(groupname).and_return(nil)
      expect(Puppet::Util::Windows::ADSI).to receive(:connect).with("WinNT://./#{groupname},group").and_return(connection)
      expect(connection).to receive(:Class).and_return('Group')

      expect(Puppet::Util::Windows::ADSI::Group.exists?(groupname)).to be_truthy
    end

    it "should be able to confirm the existence of a group with a well-known SID" do
      service_group = Puppet::Util::Windows::SID::Service
      # ensure that the underlying OS is queried here
      allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_call_original()
      expect(Puppet::Util::Windows::ADSI::Group.exists?(service_group)).to be_truthy
    end

    it "will return true with a well-known User SID, as there is no way to resolve it with a WinNT:// style moniker" do
      user = Puppet::Util::Windows::SID::NtLocal
      # ensure that the underlying OS is queried here
      allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_call_original()
      expect(Puppet::Util::Windows::ADSI::Group.exists?(user)).to be_truthy
    end

    it "should return nil with an unknown SID" do
      bogus_sid = 'S-1-2-3-4'
      # ensure that the underlying OS is queried here
      allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_call_original()
      expect(Puppet::Util::Windows::ADSI::Group.exists?(bogus_sid)).to be_falsey
    end

    it "should be able to delete a group" do
      expect(connection).to receive(:Delete).with('group', groupname)

      Puppet::Util::Windows::ADSI::Group.delete(groupname)
    end

    it "should return an enumeration of IADsGroup wrapped objects" do
      name = 'Administrators'
      wmi_groups = [double('WMI', :name => name)]
      expect(Puppet::Util::Windows::ADSI).to receive(:execquery).with('select name from win32_group where localaccount = "TRUE"').and_return(wmi_groups)

      native_object = double('IADsGroup')
      expect(Puppet::Util::Windows::SID).to receive(:octet_string_to_principal).with([]).and_return(double(:domain_account => '.\Administrator'))
      expect(native_object).to receive(:Members).and_return([double(:Name => 'Administrator', :objectSID => [], :ole_respond_to? => true)])
      expect(Puppet::Util::Windows::ADSI).to receive(:connect).with("WinNT://./#{name},group").and_return(native_object)

      groups = Puppet::Util::Windows::ADSI::Group.to_a
      expect(groups.length).to eq(1)
      expect(groups[0].name).to eq(name)
      expect(groups[0].members.map(&:domain_account)).to eq(['.\Administrator'])
    end
  end

  describe Puppet::Util::Windows::ADSI::UserProfile do
    it "should be able to delete a user profile" do
      expect(connection).to receive(:Delete).with("Win32_UserProfile.SID='S-A-B-C'")
      Puppet::Util::Windows::ADSI::UserProfile.delete('S-A-B-C')
    end

    it "should warn on 2003" do
      expect(connection).to receive(:Delete).and_raise(WIN32OLERuntimeError,
 "Delete (WIN32OLERuntimeError)
    OLE error code:80041010 in SWbemServicesEx
      Invalid class
    HRESULT error code:0x80020009
      Exception occurred.")

      expect(Puppet).to receive(:warning).with("Cannot delete user profile for 'S-A-B-C' prior to Vista SP1")
      Puppet::Util::Windows::ADSI::UserProfile.delete('S-A-B-C')
    end
  end
end
