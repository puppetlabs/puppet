require 'spec_helper'

describe Puppet::Type.type(:user).provider(:windows_adsi), :if => Puppet::Util::Platform.windows? do
  let(:resource) do
    Puppet::Type.type(:user).new(
      :title => 'testuser',
      :comment => 'Test J. User',
      :provider => :windows_adsi
    )
  end

  let(:provider) { resource.provider }

  let(:connection) { double('connection') }

  before :each do
    allow(Puppet::Util::Windows::ADSI).to receive(:computer_name).and_return('testcomputername')
    allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_return(connection)
    # this would normally query the system, but not needed for these tests
    allow(Puppet::Util::Windows::ADSI::User).to receive(:localized_domains).and_return([])
  end

  describe ".instances" do
    it "should enumerate all users" do
      names = ['user1', 'user2', 'user3']
      stub_users = names.map {|n| double(:name => n)}
      allow(connection).to receive(:execquery).with('select name from win32_useraccount where localaccount = "TRUE"').and_return(stub_users)

      expect(described_class.instances.map(&:name)).to match(names)
    end
  end

  it "should provide access to a Puppet::Util::Windows::ADSI::User object" do
    expect(provider.user).to be_a(Puppet::Util::Windows::ADSI::User)
  end

  describe "when retrieving the password property" do
    context "when the resource has a nil password" do
      it "should never issue a logon attempt" do
        allow(resource).to receive(:[]).with(eq(:name).or(eq(:password))).and_return(nil)
        expect(Puppet::Util::Windows::User).not_to receive(:logon_user)
        provider.password
      end
    end
  end

  describe "when managing groups" do
    it 'should return the list of groups as an array of strings' do
      allow(provider.user).to receive(:groups).and_return(nil)
      groups = {'group1' => nil, 'group2' => nil, 'group3' => nil}
      expect(Puppet::Util::Windows::ADSI::Group).to receive(:name_sid_hash).and_return(groups)

      expect(provider.groups).to eq(groups.keys)
    end

    it "should return an empty array if there are no groups" do
      allow(provider.user).to receive(:groups).and_return([])

      expect(provider.groups).to eq([])
    end

    it 'should be able to add a user to a set of groups' do
      resource[:membership] = :minimum
      expect(provider.user).to receive(:set_groups).with('group1,group2', true)

      provider.groups = 'group1,group2'

      resource[:membership] = :inclusive
      expect(provider.user).to receive(:set_groups).with('group1,group2', false)

      provider.groups = 'group1,group2'
    end
  end

  describe "when setting roles" do
    context "when role_membership => minimum" do
      before :each do
        resource[:role_membership] = :minimum
      end

      it "should set the given role when user has no roles" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('')

        expect(Puppet::Util::Windows::User).to receive(:set_rights).with('testuser', ['givenRole1']).and_return(nil)
        provider.roles = 'givenRole1'
      end

      it "should set only the misssing role when user already has other roles" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('givenRole1')

        expect(Puppet::Util::Windows::User).to receive(:set_rights).with('testuser', ['givenRole2']).and_return(nil)
        provider.roles = 'givenRole1,givenRole2'
      end

      it "should never remove any roles" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('givenRole1')
        allow(Puppet::Util::Windows::User).to receive(:set_rights).and_return(nil)

        expect(Puppet::Util::Windows::User).not_to receive(:remove_rights)
        provider.roles = 'givenRole1,givenRole2'
      end
    end

    context "when role_membership => inclusive" do
      before :each do
        resource[:role_membership] = :inclusive
      end

      it "should remove the unwanted role" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('givenRole1,givenRole2')

        expect(Puppet::Util::Windows::User).to receive(:remove_rights).with('testuser', ['givenRole2']).and_return(nil)
        provider.roles = 'givenRole1'
      end

      it "should add the missing role and remove the unwanted one" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('givenRole1,givenRole2')

        expect(Puppet::Util::Windows::User).to receive(:set_rights).with('testuser', ['givenRole3']).and_return(nil)
        expect(Puppet::Util::Windows::User).to receive(:remove_rights).with('testuser', ['givenRole2']).and_return(nil)
        provider.roles = 'givenRole1,givenRole3'
      end

      it "should not set any roles when the user already has given role" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('givenRole1,givenRole2')
        allow(Puppet::Util::Windows::User).to receive(:remove_rights).with('testuser', ['givenRole2']).and_return(nil)

        expect(Puppet::Util::Windows::User).not_to receive(:set_rights)
        provider.roles = 'givenRole1'
      end

      it "should set the given role when user has no roles" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('')

        expect(Puppet::Util::Windows::User).to receive(:set_rights).with('testuser', ['givenRole1']).and_return(nil)
        provider.roles = 'givenRole1'
      end

      it "should not remove any roles when user has no roles" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('')
        allow(Puppet::Util::Windows::User).to receive(:set_rights).with('testuser', ['givenRole1']).and_return(nil)

        expect(Puppet::Util::Windows::User).not_to receive(:remove_rights)
        provider.roles = 'givenRole1'
      end

      it "should remove all roles when none given" do
        allow(Puppet::Util::Windows::User).to receive(:get_rights).and_return('givenRole1,givenRole2')

        expect(Puppet::Util::Windows::User).not_to receive(:set_rights)
        expect(Puppet::Util::Windows::User).to receive(:remove_rights).with('testuser', ['givenRole1', 'givenRole2']).and_return(nil)
        provider.roles = ''
      end
    end
  end

  describe "#groups_insync?" do
    let(:group1) { double(:account => 'group1', :domain => '.', :sid => 'group1sid') }
    let(:group2) { double(:account => 'group2', :domain => '.', :sid => 'group2sid') }
    let(:group3) { double(:account => 'group3', :domain => '.', :sid => 'group3sid') }

    before :each do
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('group1', any_args).and_return(group1)
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('group2', any_args).and_return(group2)
      allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).with('group3', any_args).and_return(group3)
    end

    it "should return true for same lists of members" do
      expect(provider.groups_insync?(['group1', 'group2'], ['group1', 'group2'])).to be_truthy
    end

    it "should return true for same lists of unordered members" do
      expect(provider.groups_insync?(['group1', 'group2'], ['group2', 'group1'])).to be_truthy
    end

    it "should return true for same lists of members irrespective of duplicates" do
      expect(provider.groups_insync?(['group1', 'group2', 'group2'], ['group2', 'group1', 'group1'])).to be_truthy
    end

    it "should return true when current group(s) and should group(s) are empty lists" do
      expect(provider.groups_insync?([], [])).to be_truthy
    end

    it "should return true when current groups is empty and should groups is nil" do
      expect(provider.groups_insync?([], nil)).to be_truthy
    end

    context "when membership => inclusive" do
      before :each do
        resource[:membership] = :inclusive
      end

      it "should return true when current and should contain the same groups in a different order" do
        expect(provider.groups_insync?(['group1', 'group2', 'group3'], ['group3', 'group1', 'group2'])).to be_truthy
      end

      it "should return false when current contains different groups than should" do
        expect(provider.groups_insync?(['group1'], ['group2'])).to be_falsey
      end

      it "should return false when current is nil" do
        expect(provider.groups_insync?(nil, ['group2'])).to be_falsey
      end

      it "should return false when should is nil" do
        expect(provider.groups_insync?(['group1'], nil)).to be_falsey
      end

      it "should return false when current contains members and should is empty" do
        expect(provider.groups_insync?(['group1'], [])).to be_falsey
      end

      it "should return false when current is empty and should contains members" do
        expect(provider.groups_insync?([], ['group2'])).to be_falsey
      end

      it "should return false when should groups(s) are not the only items in the current" do
        expect(provider.groups_insync?(['group1', 'group2'], ['group1'])).to be_falsey
      end

      it "should return false when current group(s) is not empty and should is an empty list" do
        expect(provider.groups_insync?(['group1','group2'], [])).to be_falsey
      end
    end

    context "when membership => minimum" do
      before :each do
        # this is also the default
        resource[:membership] = :minimum
      end

      it "should return false when current contains different groups than should" do
        expect(provider.groups_insync?(['group1'], ['group2'])).to be_falsey
      end

      it "should return false when current is nil" do
        expect(provider.groups_insync?(nil, ['group2'])).to be_falsey
      end

      it "should return true when should is nil" do
        expect(provider.groups_insync?(['group1'], nil)).to be_truthy
      end

      it "should return true when current contains members and should is empty" do
        expect(provider.groups_insync?(['group1'], [])).to be_truthy
      end

      it "should return false when current is empty and should contains members" do
        expect(provider.groups_insync?([], ['group2'])).to be_falsey
      end

      it "should return true when current group(s) contains at least the should list" do
        expect(provider.groups_insync?(['group1','group2'], ['group1'])).to be_truthy
      end

      it "should return true when current group(s) is not empty and should is an empty list" do
        expect(provider.groups_insync?(['group1','group2'], [])).to be_truthy
      end

      it "should return true when current group(s) contains at least the should list, even unordered" do
        expect(provider.groups_insync?(['group3','group1','group2'], ['group2','group1'])).to be_truthy
      end
    end
  end

  describe "when creating a user" do
    it "should create the user on the system and set its other properties" do
      resource[:groups]     = ['group1', 'group2']
      resource[:membership] = :inclusive
      resource[:comment]    = 'a test user'
      resource[:home]       = 'C:\Users\testuser'

      user = double('user')
      expect(Puppet::Util::Windows::ADSI::User).to receive(:create).with('testuser').and_return(user)

      allow(user).to receive(:groups).and_return(['group2', 'group3'])

      expect(user).to receive(:password=).ordered
      expect(user).to receive(:commit).ordered
      expect(user).to receive(:set_groups).with('group1,group2', false).ordered
      expect(user).to receive(:[]=).with('Description', 'a test user')
      expect(user).to receive(:[]=).with('HomeDirectory', 'C:\Users\testuser')

      provider.create
    end

    it "should load the profile if managehome is set" do
      resource[:password] = '0xDeadBeef'
      resource[:managehome] = true

      user = double('user')
      allow(user).to receive(:password=)
      allow(user).to receive(:commit)
      allow(user).to receive(:[]=)
      expect(Puppet::Util::Windows::ADSI::User).to receive(:create).with('testuser').and_return(user)
      expect(Puppet::Util::Windows::User).to receive(:load_profile).with('testuser', '0xDeadBeef')

      provider.create
    end

    it "should set a user's password" do
      expect(provider.user).to receive(:disabled?).and_return(false)
      expect(provider.user).to receive(:locked_out?).and_return(false)
      expect(provider.user).to receive(:expired?).and_return(false)
      expect(provider.user).to receive(:password=).with('plaintextbad')

      provider.password = "plaintextbad"
    end

    it "should test a valid user password" do
      resource[:password] = 'plaintext'
      expect(provider.user).to receive(:password_is?).with('plaintext').and_return(true)

      expect(provider.password).to eq('plaintext')

    end

    it "should test a bad user password" do
      resource[:password] = 'plaintext'
      expect(provider.user).to receive(:password_is?).with('plaintext').and_return(false)

      expect(provider.password).to be_nil
    end

    it "should test a blank user password" do
      resource[:password] = ''
      expect(provider.user).to receive(:password_is?).with('').and_return(true)

      expect(provider.password).to eq('')
    end

    it 'should not create a user if a group by the same name exists' do
      expect(Puppet::Util::Windows::ADSI::User).to receive(:create).with('testuser').and_raise(Puppet::Error.new("Cannot create user if group 'testuser' exists."))
      expect{ provider.create }.to raise_error( Puppet::Error,
        /Cannot create user if group 'testuser' exists./ )
    end

    it "should fail with an actionable message when trying to create an active directory user" do
      resource[:name] = 'DOMAIN\testdomainuser'
      expect(Puppet::Util::Windows::ADSI::Group).to receive(:exists?).with(resource[:name]).and_return(false)
      expect(connection).to receive(:Create)
      expect(connection).to receive(:Get).with('UserFlags')
      expect(connection).to receive(:Put).with('UserFlags', true)
      expect(connection).to receive(:SetInfo).and_raise(WIN32OLERuntimeError.new("(in OLE method `SetInfo': )\n    OLE error code:8007089A in Active Directory\n      The specified username is invalid.\r\n\n    HRESULT error code:0x80020009\n      Exception occurred."))

      expect{ provider.create }.to raise_error(Puppet::Error)
    end
  end

  it 'should be able to test whether a user exists' do
    allow(Puppet::Util::Windows::SID).to receive(:name_to_principal).and_return(nil)
    allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_return(double('connection', :Class => 'User'))
    expect(provider).to be_exists

    allow(Puppet::Util::Windows::ADSI).to receive(:connect).and_return(nil)
    expect(provider).not_to be_exists
  end

  it 'should be able to delete a user' do
    expect(connection).to receive(:Delete).with('user', 'testuser')

    provider.delete
  end

  it 'should not run commit on a deleted user' do
    expect(connection).to receive(:Delete).with('user', 'testuser')
    expect(connection).not_to receive(:SetInfo)

    provider.delete
    provider.flush
  end

  it 'should delete the profile if managehome is set' do
    resource[:managehome] = true

    sid = 'S-A-B-C'
    expect(Puppet::Util::Windows::SID).to receive(:name_to_sid).with('testuser').and_return(sid)
    expect(Puppet::Util::Windows::ADSI::UserProfile).to receive(:delete).with(sid)
    expect(connection).to receive(:Delete).with('user', 'testuser')

    provider.delete
  end

  it "should commit the user when flushed" do
    expect(provider.user).to receive(:commit)

    provider.flush
  end

  it "should return the user's SID as uid" do
    expect(Puppet::Util::Windows::SID).to receive(:name_to_sid).with('testuser').and_return('S-1-5-21-1362942247-2130103807-3279964888-1111')

    expect(provider.uid).to eq('S-1-5-21-1362942247-2130103807-3279964888-1111')
  end

  it "should fail when trying to manage the uid property" do
    expect(provider).to receive(:fail).with(/uid is read-only/)
    provider.send(:uid=, 500)
  end

  [:gid, :shell].each do |prop|
    it "should fail when trying to manage the #{prop} property" do
      expect(provider).to receive(:fail).with(/No support for managing property #{prop}/)
      provider.send("#{prop}=", 'foo')
    end
  end
end
