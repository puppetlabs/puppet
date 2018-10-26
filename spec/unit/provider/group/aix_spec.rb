require 'spec_helper'

describe 'Puppet::Type::Group::Provider::Aix' do
  let(:provider_class) { Puppet::Type.type(:group).provider(:aix) }

  let(:resource) do
    Puppet::Type.type(:group).new(
      :name   => 'test_aix_user',
      :ensure => :present
    )
  end
  let(:provider) do
    provider_class.new(resource)
  end

  describe '.find' do
    let(:groups) do
      objects = [
        { :name => 'group1', :id => '1' },
        { :name => 'group2', :id => '2' }
      ]

      objects
    end

    let(:ia_module_args) { [ '-R', 'module' ] }

    let(:expected_group) do
      {
        :name => 'group1',
        :gid  => 1
      }
    end

    before(:each) do
      provider_class.stubs(:list_all).with(ia_module_args).returns(groups)
    end

    it 'raises an ArgumentError if the group does not exist' do
      expect do
        provider_class.find('non_existent_group', ia_module_args)
      end.to raise_error do |error|
        expect(error).to be_a(ArgumentError)

        expect(error.message).to match('non_existent_group')
      end
    end

    it 'can find the group when passed-in a group name' do
      expect(provider_class.find('group1', ia_module_args)).to eql(expected_group)
    end

    it 'can find the group when passed-in the gid' do
      expect(provider_class.find(1, ia_module_args)).to eql(expected_group)
    end
  end

  describe '.users_to_members' do
    it 'converts the users attribute to the members property' do
      expect(provider_class.users_to_members('foo,bar'))
        .to eql(['foo', 'bar'])
    end
  end

  describe '.members_to_users' do
    context 'when auth_membership == true' do
      before(:each) do
        resource[:auth_membership] = true
      end

      it 'returns only the passed-in members' do
        expect(provider_class.members_to_users(provider, ['user1', 'user2']))
          .to eql('user1,user2')
      end
    end

    context 'when auth_membership == false' do
      before(:each) do
        resource[:auth_membership] = false

        provider.stubs(:members).returns(['user3', 'user1'])
      end

      it 'adds the passed-in members to the current list of members, filtering out any duplicates' do
        expect(provider_class.members_to_users(provider, ['user1', 'user2']))
          .to eql('user1,user2,user3')
      end
    end
  end
end
