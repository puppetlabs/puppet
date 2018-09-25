require 'spec_helper'

describe 'Puppet::Type::User::Provider::Aix' do
  let(:provider_class) { Puppet::Type.type(:user).provider(:aix) }
  let(:group_provider_class) { Puppet::Type.type(:group).provider(:aix) }

  let(:resource) do
    Puppet::Type.type(:user).new(
      :name   => 'test_aix_user',
      :ensure => :present
    )
  end
  let(:provider) do
    provider_class.new(resource)
  end

  describe '.pgrp_to_gid' do
    it "finds the primary group's gid" do
      provider.stubs(:ia_module_args).returns(['-R', 'module'])

      group_provider_class.expects(:list_all)
        .with(provider.ia_module_args)
        .returns([{ :name => 'group', :id => 1}])

      expect(provider_class.pgrp_to_gid(provider, 'group')).to eql(1)
    end
  end

  describe '.gid_to_pgrp' do
    it "finds the gid's primary group" do
      provider.stubs(:ia_module_args).returns(['-R', 'module'])

      group_provider_class.expects(:list_all)
        .with(provider.ia_module_args)
        .returns([{ :name => 'group', :id => 1}])

      expect(provider_class.gid_to_pgrp(provider, 1)).to eql('group')
    end
  end

  describe '.expires_to_expiry' do
    it 'returns absent if expires is 0' do
      expect(provider_class.expires_to_expiry(provider, '0')).to eql(:absent)
    end

    it 'returns absent if the expiry attribute is not formatted properly' do
      expect(provider_class.expires_to_expiry(provider, 'bad_format')).to eql(:absent)
    end

    it 'returns the password expiration date' do
      expect(provider_class.expires_to_expiry(provider, '0910122314')).to eql('2014-09-10')
    end
  end

  describe '.expiry_to_expires' do
    it 'returns 0 if the expiry date is 0000-00-00' do
      expect(provider_class.expiry_to_expires('0000-00-00')).to eql('0')
    end

    it 'returns 0 if the expiry date is "absent"' do
      expect(provider_class.expiry_to_expires('absent')).to eql('0')
    end

    it 'returns 0 if the expiry date is :absent' do
      expect(provider_class.expiry_to_expires(:absent)).to eql('0')
    end

    it 'returns the expires attribute value' do
      expect(provider_class.expiry_to_expires('2014-09-10')).to eql('0910000014')
    end
  end

  describe '.groups_attribute_to_property' do
    it "reads the user's groups from the etc/groups file" do
      groups = ['system', 'adm']
      Puppet::Util::POSIX.stubs(:groups_of).with(resource[:name]).returns(groups)

      actual_groups = provider_class.groups_attribute_to_property(provider, 'unused_value')
      expected_groups = groups.join(',')

      expect(actual_groups).to eql(expected_groups)
    end
  end

  describe '.groups_property_to_attribute' do
    it 'raises an ArgumentError if the groups are space-separated' do
      groups = "foo bar baz"
      expect do
        provider_class.groups_property_to_attribute(groups)
      end.to raise_error do |error|
        expect(error).to be_a(ArgumentError)

        expect(error.message).to match(groups)
        expect(error.message).to match("Groups")
      end
    end
  end

  describe '#gid=' do
    let(:value) { 'new_pgrp' }

    let(:old_pgrp) { 'old_pgrp' }
    let(:cur_groups) { 'system,adm' }
    before(:each) do
      provider.stubs(:gid).returns(old_pgrp)
      provider.stubs(:groups).returns(cur_groups)
      provider.stubs(:set)
    end

    it 'raises a Puppet::Error if it fails to set the groups property' do
      provider.stubs(:set)
        .with(:groups, cur_groups)
        .raises(Puppet::ExecutionFailure, 'failed to reset the groups!')

      expect { provider.gid = value }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match('groups')
        expect(error.message).to match(cur_groups)
        expect(error.message).to match(old_pgrp)
        expect(error.message).to match(value)
      end
    end
  end

  describe '#parse_password' do
    def call_parse_password
      File.open(my_fixture('aix_passwd_file.out')) do |f|
        provider.parse_password(f)
      end
    end

    it "returns :absent if the user stanza doesn't exist" do
      resource[:name] = 'nonexistent_user'
      expect(call_parse_password).to eql(:absent)
    end

    it "returns absent if the user does not have a password" do
      resource[:name] = 'no_password_user'
      expect(call_parse_password).to eql(:absent)
    end

    it "returns the user's password" do
      expect(call_parse_password).to eql('some_password')
    end
  end

  # TODO: If we move from using Mocha to rspec's mocks,
  # or a better and more robust mocking library, we should
  # remove #parse_password and copy over its tests to here.
  describe '#password' do
  end

  describe '#password=' do
    let(:mock_tempfile) do
      mock_tempfile_obj = mock()
      mock_tempfile_obj.stubs(:<<)
      mock_tempfile_obj.stubs(:close)
      mock_tempfile_obj.stubs(:delete)
      mock_tempfile_obj.stubs(:path).returns('tempfile_path')

      Tempfile.stubs(:new)
        .with("puppet_#{provider.name}_pw", :encoding => Encoding::ASCII)
        .returns(mock_tempfile_obj)

      mock_tempfile_obj
    end
    let(:cmd) do
      [provider.class.command(:chpasswd), *provider.ia_module_args, '-e', '-c']
    end
    let(:execute_options) do
      {
        :failonfail => false,
        :combine => true,
        :stdinfile => mock_tempfile.path
      }
    end

    it 'raises a Puppet::Error if chpasswd fails' do
      provider.stubs(:execute).with(cmd, execute_options).returns("failed to change passwd!")
      expect { provider.password = 'foo' }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match("failed to change passwd!")
      end
    end

    it "changes the user's password" do
      provider.expects(:execute).with(cmd, execute_options).returns("")
      provider.password = 'foo'
    end

    it "closes and deletes the tempfile" do
      provider.stubs(:execute).with(cmd, execute_options).returns("")

      mock_tempfile.expects(:close).times(2)
      mock_tempfile.expects(:delete)

      provider.password = 'foo'
    end
  end

  describe '#create' do
    it 'should create the user' do
      provider.resource.stubs(:should).with(anything).returns(nil)
      provider.resource.stubs(:should).with(:groups).returns('g1,g2')
      provider.resource.stubs(:should).with(:password).returns('password')

      provider.expects(:execute)
      provider.expects(:groups=).with('g1,g2')
      provider.expects(:password=).with('password')

      provider.create
    end
  end
end
