module Puppet::DataProviders

  def self.assert_loaded
    unless @loaded
      require 'puppet/pops'
      require 'puppet/data_providers/data_adapter'
    end
    @loaded = true
  end

  # @deprecated
  def self.lookup_in_environment(name, lookup_invocation, merge)
    adapter.lookup_in_environment(name, lookup_invocation, merge)
  end

  MODULE_NAME = 'module_name'.freeze

  # @deprecated
  def self.lookup_in_module(name, lookup_invocation, merge)
    adapter.lookup_in_module(name, lookup_invocation, merge)
  end

  def self.adapter(lookup_invocation)
    assert_loaded()
    DataAdapter.adapt(lookup_invocation.scope.environment)
  end
end
