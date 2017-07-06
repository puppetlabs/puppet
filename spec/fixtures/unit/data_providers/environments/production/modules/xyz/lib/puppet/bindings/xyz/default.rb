Puppet::Bindings.newbindings('xyz::default') do
  # In the default bindings for this module
  bind {
    # bind its name to the 'puppet' environment data provider
    name         'xyz'
    to           'function'
    in_multibind 'puppet::module_data'
 }
end
