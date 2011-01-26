#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

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
