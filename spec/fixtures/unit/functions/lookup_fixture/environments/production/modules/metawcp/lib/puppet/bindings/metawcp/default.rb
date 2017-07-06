Puppet::Bindings.newbindings('metawcp::default') do
  # Make the SampleModuleData provider available for use in modules
  # as 'sample'.
  #
  bind {
    name 'sample'
    in_multibind 'puppet::module_data_providers'
    to_instance 'PuppetX::Thallgren::SampleModuleData'
  }
end
