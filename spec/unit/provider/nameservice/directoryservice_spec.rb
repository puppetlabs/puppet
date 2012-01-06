#!/usr/bin/env rspec
require 'spec_helper'

# We use this as a reasonable way to obtain all the support infrastructure.
[:user, :group].each do |type_for_this_round|
  provider_class = Puppet::Type.type(type_for_this_round).provider(:directoryservice)

  describe provider_class do
    before do
      @resource = stub("resource")
      @provider = provider_class.new(@resource)
    end

    it "[#6009] should handle nested arrays of members" do
      current = ["foo", "bar", "baz"]
      desired = ["foo", ["quux"], "qorp"]
      group   = 'example'

      @resource.stubs(:[]).with(:name).returns(group)
      @resource.stubs(:[]).with(:auth_membership).returns(true)
      @provider.instance_variable_set(:@property_value_cache_hash,
                                      { :members => current })

      %w{bar baz}.each do |del|
        @provider.expects(:execute).once.
          with([:dseditgroup, '-o', 'edit', '-n', '.', '-d', del, group])
      end

      %w{quux qorp}.each do |add|
        @provider.expects(:execute).once.
          with([:dseditgroup, '-o', 'edit', '-n', '.', '-a', add, group])
      end

      expect { @provider.set(:members, desired) }.should_not raise_error
    end
  end
end

describe 'DirectoryService.single_report' do
  it 'should fail on OS X < 10.4' do
    Puppet::Provider::NameService::DirectoryService.stubs(:get_macosx_version_major).returns("10.3")

    lambda {
      Puppet::Provider::NameService::DirectoryService.single_report('resource_name')
    }.should raise_error(RuntimeError, "Puppet does not support OS X versions < 10.4")
  end

  it 'should use url data on 10.4' do
    Puppet::Provider::NameService::DirectoryService.stubs(:get_macosx_version_major).returns("10.4")
    Puppet::Provider::NameService::DirectoryService.stubs(:get_ds_path).returns('Users')
    Puppet::Provider::NameService::DirectoryService.stubs(:list_all_present).returns(
      ['root', 'user1', 'user2', 'resource_name']
    )
    Puppet::Provider::NameService::DirectoryService.stubs(:generate_attribute_hash)
    Puppet::Provider::NameService::DirectoryService.stubs(:execute)
    Puppet::Provider::NameService::DirectoryService.expects(:parse_dscl_url_data)

    Puppet::Provider::NameService::DirectoryService.single_report('resource_name')
  end

  it 'should use plist data on > 10.4' do
    Puppet::Provider::NameService::DirectoryService.stubs(:get_macosx_version_major).returns("10.5")
    Puppet::Provider::NameService::DirectoryService.stubs(:get_ds_path).returns('Users')
    Puppet::Provider::NameService::DirectoryService.stubs(:list_all_present).returns(
      ['root', 'user1', 'user2', 'resource_name']
    )
    Puppet::Provider::NameService::DirectoryService.stubs(:generate_attribute_hash)
    Puppet::Provider::NameService::DirectoryService.stubs(:execute)
    Puppet::Provider::NameService::DirectoryService.expects(:parse_dscl_plist_data)

    Puppet::Provider::NameService::DirectoryService.single_report('resource_name')
  end
end

describe 'DirectoryService.get_exec_preamble' do
  it 'should fail on OS X < 10.4' do
    Puppet::Provider::NameService::DirectoryService.stubs(:get_macosx_version_major).returns("10.3")

    lambda {
      Puppet::Provider::NameService::DirectoryService.get_exec_preamble('-list')
    }.should raise_error(RuntimeError, "Puppet does not support OS X versions < 10.4")
  end

  it 'should use url data on 10.4' do
    Puppet::Provider::NameService::DirectoryService.stubs(:get_macosx_version_major).returns("10.4")
    Puppet::Provider::NameService::DirectoryService.stubs(:get_ds_path).returns('Users')

    Puppet::Provider::NameService::DirectoryService.get_exec_preamble('-list').should include("-url")
  end

  it 'should use plist data on > 10.4' do
    Puppet::Provider::NameService::DirectoryService.stubs(:get_macosx_version_major).returns("10.5")
    Puppet::Provider::NameService::DirectoryService.stubs(:get_ds_path).returns('Users')

    Puppet::Provider::NameService::DirectoryService.get_exec_preamble('-list').should include("-plist")
  end
end
