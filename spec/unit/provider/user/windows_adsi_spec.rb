#!/usr/bin/env ruby

require 'spec_helper'

# TODO: Some of these tests test dependencies that are beyond the scope
# of unit tests. For example, there's a lot of ADSI::User mocking going
# on. At some point, these should either be moved to integration tests,
# refactored to conform more to unit test standards, or be removed
# entirely.
describe Puppet::Type.type(:user).provider(:windows_adsi), :if => Puppet.features.microsoft_windows? do
  let(:resource) do
    Puppet::Type.type(:user).new(
      :title => 'testuser',
      :comment => 'Test J. User',
      :provider => :windows_adsi
    )
  end

  let(:provider) { resource.provider }
  let(:provider_class) { provider.class }

  let(:connection) { stub 'connection' }

  def stub_attributes(attributes)
    resource[:attributes] = attributes

    # When referencing resource[:attributes] in the provider code,
    # we reference the #should method of the attributes property.
    # This calls our getter, which is why we need to stub it here.
    provider.stubs(:attributes).returns(attributes) 
  end

  before :each do
    Puppet::Util::Windows::ADSI.stubs(:computer_name).returns('testcomputername')
    Puppet::Util::Windows::ADSI.stubs(:connect).returns connection
    # this would normally query the system, but not needed for these tests
    Puppet::Util::Windows::ADSI::User.stubs(:localized_domains).returns([])
  end

  describe '.munge_string' do
    it "returns the value as-is" do
      expect(provider_class.munge_string('foo')).to eql('foo')
    end
  end

  describe '.unmunge_string' do
    it "raises an ArgumentError if an empty string is passed-in" do
      expect do
        provider_class.unmunge_string('')
      end.to raise_error do |error|
        expect(error).to be_a(ArgumentError)

        expect(error.message).to match('empty string')
      end
    end

    it "returns a non-empty string value as-is" do
      expect(provider_class.unmunge_string('foo')).to eql('foo')
    end
  end

  describe '.munge_bit' do
    it "munges 1 to 'true'" do
      expect(provider_class.munge_bit(1)).to eql('true')
    end

    it "munges 0 to 'false'" do
      expect(provider_class.munge_bit(0)).to eql('false')
    end

    it "raises an ArgumentError for a value other than '0' or '1'" do
      expect { provider_class.munge_bit('bad_value') }.to raise_error do |error|
        expect(error).to be_a(ArgumentError)
        expect(error.message).to match('Bit')
      end
    end
  end

  describe '.unmunge_bit' do
    it "unmunges 'true' to 1" do
      expect(provider_class.unmunge_bit('true')).to eql(1)
    end

    it "unmunges 'false' to 0" do
      expect(provider_class.unmunge_bit('false')).to eql(0)
    end

    it "raises an ArgumentError for a value other than 'true' or 'false'" do
      expect { provider_class.unmunge_bit('bad_value') }.to raise_error do |error|
        expect(error).to be_a(ArgumentError)
        expect(error.message).to match('Boolean')
      end
    end
  end

  describe ".instances" do
    it "should enumerate all users" do
      names = ['user1', 'user2', 'user3']
      stub_users = names.map{|n| stub(:name => n)}
      connection.stubs(:execquery).with('select name from win32_useraccount where localaccount = "TRUE"').returns(stub_users)

      expect(described_class.instances.map(&:name)).to match(names)
    end
  end

  it "should provide access to a Puppet::Util::Windows::ADSI::User object" do
    expect(provider.user).to be_a(Puppet::Util::Windows::ADSI::User)
  end

  describe "when retrieving the password property" do
    context "when the resource has a nil password" do
      it "should never issue a logon attempt" do
        resource.stubs(:[]).with(any_of(:name, :password)).returns(nil)
        Puppet::Util::Windows::User.expects(:logon_user).never
        provider.password
      end
    end
  end

  describe '#password=' do
    before(:each) do
      provider.user.stubs(:password=)

      provider.stubs(:attributes).returns({})
      provider.stubs(:attributes=).with(anything)

      provider.user.stubs(:locked_out?).returns(false)
      provider.user.stubs(:expired?).returns(false)
    end

    context "when the attributes property is not managed" do
      it "sets the user's password" do
        provider.user.expects(:password=).with('password')
        provider.expects(:attributes=).with(password_never_expires: 'true')
        provider.user.expects(:commit)

        provider.password = 'password'
      end

      it "raises a Puppet::Error if it fails to set the password to never expire" do
        provider.stubs(:attributes=)
          .with(password_never_expires: 'true')
          .raises(Puppet::Error, 'failed!')

        expect do
          provider.password = 'password'
        end.to raise_error do |error|
          expect(error).to be_a(Puppet::Error)

          expect(error.message).to match('re-running Puppet')
          expect(error.message).to match('failed!')
        end
      end
    end

    context "when the attributes property is managed" do
      before(:each) do
        stub_attributes(full_name: 'mock_full_name')
      end

      it "it marks the password for syncing later in the #flush method" do
        provider.user.expects(:password=).with('password').never

        provider.password = 'password'

        expect(provider.instance_variable_get(:@sync_password)).to be true
      end
    end
  end

  describe '#attributes' do
    before(:each) do
      provider.user.stubs(:userflag_set?)

      # Need to stub PasswordExpired separately so that munge_bit
      # does not throw an exception.
      provider.user.stubs(:[])
      provider.user.stubs(:[]).with('PasswordExpired').returns(0)
    end

    shared_examples 'retrieving an adsi property attribute' do |name, property, munge, stub_value|
      before(:each) do
        if munge.is_a?(Symbol)
          munge = provider_class.method(munge)
        end
      end

      it "retrieves the #{name} attribute's value" do
        provider.user.stubs(:[]).with(property).returns(stub_value)

        expect(provider.attributes).to include(name => munge.call(stub_value))
      end
    end

    shared_examples 'retrieving a userflag attribute' do |name, flag|
      it "retrieves the #{name} attribute's value" do
        provider.user.stubs(:userflag_set?).with(flag).returns(true)

        expect(provider.attributes).to include(name => 'true')
      end
    end

    include_examples 'retrieving an adsi property attribute',
                     :full_name,
                     'FullName',
                     lambda { |x| x },
                     'mock full name'

    include_examples 'retrieving an adsi property attribute',
                     :password_change_required,
                     'PasswordExpired',
                     :munge_bit,
                     0

    include_examples 'retrieving a userflag attribute',
                     :disabled,
                     :ADS_UF_ACCOUNTDISABLE

    include_examples 'retrieving a userflag attribute',
                     :password_change_not_allowed,
                     :ADS_UF_PASSWD_CANT_CHANGE

    include_examples 'retrieving a userflag attribute',
                     :password_never_expires,
                     :ADS_UF_DONT_EXPIRE_PASSWD

    it 'retrieves all of the current attributes on the system' do
      # ADSI property attribute expectations
      provider.user.stubs(:[]).with('FullName').returns('mock_full_name')
      provider.user.stubs(:[]).with('PasswordExpired').returns(0)

      # ADSI userflag attribute expectations
      [
        :ADS_UF_ACCOUNTDISABLE,
        :ADS_UF_PASSWD_CANT_CHANGE,
        :ADS_UF_DONT_EXPIRE_PASSWD
      ].each do |flag|
        provider.user.stubs(:userflag_set?).with(flag).returns(true)
      end

      expected_attributes = {
        disabled: 'true',
        password_change_not_allowed: 'true',
        password_never_expires: 'true',
        full_name: 'mock_full_name',
        password_change_required: 'false'
      }

      expect(provider.attributes).to eql(expected_attributes)
    end
  end

  describe "#validate_attributes" do
    it "should fail if the new attributes contain any unmanaged attributes" do
      unmanaged_attributes = {
        :attribute_one => 'value_one',
        :attribute_two => 'value_two'
      }

      new_attributes = {
        :disabled => 'true',
        :password_change_required => 'true'
      }.merge(unmanaged_attributes)

      expect do
        provider.validate_attributes(new_attributes)
      end.to raise_error(
        ArgumentError,
        /#{unmanaged_attributes.keys.join(', ')}.*#{provider.managed_attributes.keys.join(', ')}/
      )
    end

    it "should fail if the new attributes set password_change_not_allowed to true and password_change_required to true" do
      new_attributes = {
        password_change_not_allowed: 'true',
        password_change_required: 'true'
      }

      expect do
        provider.validate_attributes(new_attributes)
      end.to raise_error(
        ArgumentError,
        /password_change_not_allowed.*password_change_required/
      )
    end

    it "should fail if the new attributes set password_change_required to true and password_never_expires to true" do
      new_attributes = {
        password_change_required: 'true',
        password_never_expires: 'true'
      }

      expect do
        provider.validate_attributes(new_attributes)
      end.to raise_error(
        ArgumentError,
        /password_change_required.*password_never_expires/
      )
    end

    it "should pass if the new attributes are valid" do
      new_attributes = {
        :disabled => 'true',
        :password_change_required => 'true'
      }

      expect do
        provider.validate_attributes(new_attributes)
      end.to_not raise_error
    end
  end

  describe "#attributes=" do
    before(:each) do
      provider.stubs(:validate_attributes)

      # Need to stub PasswordExpired separately so that munge_bit
      # does not throw an exception.
      provider.user.stubs(:[]).with(anything).returns(nil)
      provider.user.stubs(:[]).with('PasswordExpired').returns(0)
      provider.user.stubs(:[]=).with(anything, anything)

      provider.user.stubs(:userflag_set?).with(anything).returns(nil)
      provider.user.stubs(:set_userflags).with(anything)
      provider.user.stubs(:unset_userflags).with(anything)

      provider.user.stubs(:commit)
    end

    shared_examples "wrapping an error" do |error_type|
      it "wraps an #{error_type} into a Puppet::Error" do
        attributes = {}

        provider.stubs(:validate_attributes)
          .with(attributes)
          .raises(error_type, 'Error!')

        expect do
          provider.attributes = attributes
        end.to raise_error do |error|
          expect(error).to be_a(Puppet::Error)

          expect(error.message).to match("attributes property")
          expect(error.message).to match("#{resource.class.name}\\[#{provider.resource.name}\\]")
          expect(error.message).to match('Error!')
        end
      end
    end

    shared_examples 'setting an adsi property attribute' do |name, property, unmunge, stub_value|
      context "setting the #{name} attribute's value" do
        before(:each) do
          if unmunge.is_a?(Symbol)
            unmunge = provider_class.method(unmunge)
          end
        end

        it "wraps an ArgumentError into a Puppet::Error" do
          provider.user.stubs(:[]=).raises(ArgumentError, "ArgumentError raised!")

          expect do
            provider.attributes = { name => stub_value }
          end.to raise_error do |error|
            expect(error).to be_a(Puppet::Error)

            expect(error.message).to match(name.to_s)
            expect(error.message).to match(stub_value)
            expect(error.message).to match('ArgumentError')
          end
        end

        it "sets the value" do
          provider.user.expects(:[]=).with(property, unmunge.call(stub_value))

          provider.attributes = { name => stub_value }
        end
      end
    end

    shared_examples 'setting a userflag attribute' do |name, flag|
      context "setting the #{name} attribute's value" do
        before(:each) do
          provider.user.stubs(:userflag_set?).with(flag).returns(nil)
        end

        it "raises an error if a non-Boolean value is passed-in" do
          expect do
            provider.attributes = { name => 'bad_value' }
          end.to raise_error do |error|
            expect(error.message).to match('bad_value')
            expect(error.message).to match('Boolean')
          end
        end

        it "wraps an ArgumentError into a Puppet::Error" do
          expect do
            provider.attributes = { name => 'bad_value'}
          end.to raise_error do |error|
            expect(error).to be_a(Puppet::Error)

            expect(error.message).to match(name.to_s)
            expect(error.message).to match('bad_value')
            expect(error.message).to match('Boolean')
          end
        end

        it "sets the userflag #{flag} if value == 'true'" do
          provider.user.expects(:set_userflags).with(flag)

          provider.attributes = { name => 'true' }
        end

        it "unsets the userflag #{flag} if value == 'false'" do
          provider.user.expects(:unset_userflags).with(flag)

          provider.attributes = { name => 'false' }
        end
      end
    end

    include_examples 'setting an adsi property attribute',
                     :full_name,
                     'FullName',
                     lambda { |x| x },
                     'mock full name'

    include_examples 'setting an adsi property attribute',
                     :password_change_required,
                     'PasswordExpired',
                     :unmunge_bit,
                     'true'

    include_examples 'setting a userflag attribute',
                     :disabled,
                     :ADS_UF_ACCOUNTDISABLE

    include_examples 'setting a userflag attribute',
                     :password_change_not_allowed,
                     :ADS_UF_PASSWD_CANT_CHANGE

    include_examples 'setting a userflag attribute',
                     :password_never_expires,
                     :ADS_UF_DONT_EXPIRE_PASSWD

    include_examples 'wrapping an error', ArgumentError
    include_examples 'wrapping an error', Puppet::Error

    it 'validates the attributes before setting them' do
      attributes = { full_name: 'mock_full_name' }

      provider.user.stubs(:[]).with(anything).returns(nil)

      provider.expects(:validate_attributes).with(attributes)

      provider.attributes = attributes
    end

    it 'sets all of the attributes on the system' do
      attributes = {
        disabled: 'true',
        password_change_not_allowed: 'true',
        password_never_expires: 'true',
        full_name: 'mock_full_name',
        password_change_required: 'true'
      }

      # ADSI property attribute expectations
      provider.user.expects(:[]=).with('FullName', 'mock_full_name')
      provider.user.expects(:[]=).with('PasswordExpired', 1)

      # ADSI userflag attribute expectations
      [
        :ADS_UF_ACCOUNTDISABLE,
        :ADS_UF_PASSWD_CANT_CHANGE,
        :ADS_UF_DONT_EXPIRE_PASSWD
      ].each do |flag|
        provider.user.expects(:set_userflags).with(flag)
      end

      provider.attributes = attributes
    end
  end

  describe "when managing groups" do
    it 'should return the list of groups as an array of strings' do
      provider.user.stubs(:groups).returns nil
      groups = {'group1' => nil, 'group2' => nil, 'group3' => nil}
      Puppet::Util::Windows::ADSI::Group.expects(:name_sid_hash).returns(groups)

      expect(provider.groups).to eq(groups.keys)
    end

    it "should return an empty array if there are no groups" do
      provider.user.stubs(:groups).returns []

      expect(provider.groups).to eq([])
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

  describe "#groups_insync?" do

    let(:group1) { stub(:account => 'group1', :domain => '.', :sid => 'group1sid') }
    let(:group2) { stub(:account => 'group2', :domain => '.', :sid => 'group2sid') }
    let(:group3) { stub(:account => 'group3', :domain => '.', :sid => 'group3sid') }

    before :each do
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with('group1').returns(group1)
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with('group2').returns(group2)
      Puppet::Util::Windows::SID.stubs(:name_to_principal).with('group3').returns(group3)
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

      stub_attributes({ disabled: 'true' })

      # This should be invoked later in create
      provider.expects(:attributes=).with(resource[:attributes])

      user = stub 'user'
      Puppet::Util::Windows::ADSI::User.expects(:create).with('testuser').returns user

      user.stubs(:groups).returns(['group2', 'group3'])

      create = sequence('create')
      user.expects(:password=).with(nil).in_sequence(create)
      user.expects(:set_groups).with('group1,group2', false).in_sequence(create)
      user.expects(:[]=).with('Description', 'a test user')
      user.expects(:[]=).with('HomeDirectory', 'C:\Users\testuser')

      provider.create
    end

    it "should load the profile if managehome is set" do
      resource[:password] = '0xDeadBeef'
      resource[:managehome] = true

      provider.stubs(:attributes).returns({})
      provider.stubs(:password=)

      user = stub_everything 'user'
      Puppet::Util::Windows::ADSI::User.expects(:create).with('testuser').returns user
      Puppet::Util::Windows::User.expects(:load_profile).with('testuser', '0xDeadBeef')

      provider.create
    end

    it "should test a valid user password" do
      resource[:password] = 'plaintext'
      provider.user.expects(:password_is?).with('plaintext').returns true

      expect(provider.password).to eq('plaintext')

    end

    it "should test a bad user password" do
      resource[:password] = 'plaintext'
      provider.user.expects(:password_is?).with('plaintext').returns false

      expect(provider.password).to be_nil
    end

    it "should test a blank user password" do
      resource[:password] = ''
      provider.user.expects(:password_is?).with('').returns true

      expect(provider.password).to eq('')
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
      connection.stubs(:Get)
      connection.stubs(:Get).with('UserFlags').returns(0)
      connection.stubs(:Put)
      connection.expects(:SetInfo).raises( WIN32OLERuntimeError.new("(in OLE method `SetInfo': )\n    OLE error code:8007089A in Active Directory\n      The specified username is invalid.\r\n\n    HRESULT error code:0x80020009\n      Exception occurred."))

      expect{ provider.create }.to raise_error(Puppet::Error)
    end
  end

  it 'should be able to test whether a user exists' do
    Puppet::Util::Windows::SID.stubs(:name_to_principal).returns(nil)
    Puppet::Util::Windows::ADSI.stubs(:connect).returns stub('connection', :Class => 'User')
    expect(provider).to be_exists

    Puppet::Util::Windows::ADSI.stubs(:connect).returns nil
    expect(provider).not_to be_exists
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

  describe '#flush' do
    before(:each) do
      provider.user.stubs(:commit)

      provider.user.stubs(:locked_out?).returns(false)
      provider.user.stubs(:expired?).returns(false)
    end

    context "when the password needs to be synced" do
      before(:each) do
        stub_attributes(password_never_expires: 'true', password_change_required: 'false')
        provider.instance_variable_set(:@sync_password, true)
      end

      it "sets the user's password when a password is specified" do
        resource[:password] = 'password'

        provider.user.expects(:password=).with('password')
        provider.expects(:attributes=).with(anything).never

        provider.flush
      end
    end

    it "should commit the user" do
      provider.user.expects(:commit)
  
      provider.flush
    end
  end

  it "should return the user's SID as uid" do
    Puppet::Util::Windows::SID.expects(:name_to_sid).with('testuser').returns('S-1-5-21-1362942247-2130103807-3279964888-1111')

    expect(provider.uid).to eq('S-1-5-21-1362942247-2130103807-3279964888-1111')
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
