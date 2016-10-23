Puppet::Bindings.newbindings('backend::default') do
  # In the default bindings for this module
  bind {
    # bind its name to the 'puppet' environment data provider
    name         'special'
    in_multibind "puppet::path_based_data_provider_factories"
    to_instance "PuppetX::Backend::SpecialDataProviderFactory"
 }
end
