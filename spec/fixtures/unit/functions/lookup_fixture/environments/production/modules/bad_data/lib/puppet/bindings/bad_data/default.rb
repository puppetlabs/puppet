Puppet::Bindings.newbindings('bad_data::default') do
  # In the default bindings for this module
  bind {
    # bind its name to the 'puppet' module data provider
    name         'bad_data'
    to           'function'
    in_multibind 'puppet::module_data'
 }
end
