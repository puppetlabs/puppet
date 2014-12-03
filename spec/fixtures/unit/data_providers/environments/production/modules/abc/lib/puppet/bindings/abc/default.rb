Puppet::Bindings.newbindings('abc::default') do
  # In the default bindings for this module
  bind {
    # bind its name to the 'puppet' environment data provider
    name         'abc'
    to           'function'
    in_multibind 'puppet::module_data'
 }
end
