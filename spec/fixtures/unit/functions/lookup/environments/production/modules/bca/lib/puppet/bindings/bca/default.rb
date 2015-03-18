Puppet::Bindings.newbindings('bca::default') do
  # In the default bindings for this module
  bind {
    # bind its name to the 'puppet' module data provider
    name         'bca'
    to           'function'
    in_multibind 'puppet::module_data'
 }
end
