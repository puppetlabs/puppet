module Puppet::DataProviders

  def self.assert_loaded
    unless @loaded
      require 'puppet/pops'
      require 'puppet/data_providers/data_adapter'
      require 'puppet/data_providers/lookup_adapter'
    end
    @loaded = true
  end

  # @deprecated use `lookup_adapter(lookup_invocation).lookup` instead
  def self.lookup_in_environment(name, lookup_invocation, merge)
    Puppet.deprecation_warning('The method Puppet::DataProviders.lookup_in_environment is deprecated and will be removed in the next major release of Puppet.')
    lookup_adapter(lookup_invocation).lookup_in_environment(name, lookup_invocation, Puppet::Pops::MergeStrategy.strategy(merge))
  end

  MODULE_NAME = 'module_name'.freeze

  # @deprecated use `adapter(lookup_invocation).lookup` instead
  def self.lookup_in_module(name, lookup_invocation, merge)
    Puppet.deprecation_warning('The method Puppet::DataProviders.lookup_in_module is deprecated and will be removed in the next major release of Puppet.')
    lookup_adapter(lookup_invocation).lookup_in_module(name, lookup_invocation, Puppet::Pops::MergeStrategy.strategy(merge))
  end

  def self.lookup_adapter(lookup_invocation)
    assert_loaded()
    LookupAdapter.adapt(lookup_invocation.scope.compiler)
  end
end
