Puppet::Bindings.newbindings('dataprovider::default') do

  bind {
    name 'sample'
    in_multibind 'puppet::environment_data_providers'
    to_instance 'PuppetX::FunctionsTester::SampleEnvData'
  }

  bind {
    name 'sample'
    in_multibind 'puppet::module_data_providers'
    to_instance 'PuppetX::FunctionsTester::SampleModuleData'
  }

  bind {
    name 'dataprovider'
    to 'sample'
    in_multibind 'puppet::module_data'
  }
end

