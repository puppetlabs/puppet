module Puppet::DataProviders

  def self.assert_loaded
    unless @loaded
      require 'puppet/pops'
      require 'puppet/data_providers/data_adapter'
    end
    @loaded = true
  end

  def self.lookup_in_environment(name, scope, merge)
    assert_loaded()
    adapter = Puppet::DataProviders::DataAdapter.adapt(Puppet.lookup(:current_environment))
    adapter.env_provider.lookup(name, scope, merge)
  end

  MODULE_NAME = 'module_name'.freeze

  def self.lookup_in_module(name, scope, merge)
    # Do not attempt to do a lookup in a module if evaluated code is not in a module
    # which is detected by checking if "MODULE_NAME" exists in scope
    return nil unless scope.exist?(MODULE_NAME)

    assert_loaded()
    adapter = Puppet::DataProviders::DataAdapter.adapt(Puppet.lookup(:current_environment))
    adapter.module_provider(scope[MODULE_NAME]).lookup(name, scope, merge)
  end
end
