require 'puppet/indirector'

# A class for managing data lookups
class Puppet::DataBinding
  class LookupError < Puppet::Error; end

  # Set up indirection, so that data can be looked for in the compiler
  extend Puppet::Indirector

  indirects(:data_binding, :terminus_setting => :data_binding_terminus,
    :doc => "Where to find external data bindings.")
end
