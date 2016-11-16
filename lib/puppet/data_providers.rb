# TODO: API 5.0, remove this module
# @api private
# @deprecated
module Puppet::DataProviders

  def self.assert_loaded
    unless @loaded
      require 'puppet/pops'
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
    unless Puppet[:strict] == :off
      Puppet.deprecation_warning('The method Puppet::DataProviders.lookup_adapter is deprecated and will be removed in the next major release of Puppet.')
    end
    assert_loaded()
    Puppet::Pops::Lookup::LookupAdapter.adapt(lookup_invocation.scope.compiler)
  end
end
