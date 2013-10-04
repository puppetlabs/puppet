require 'puppet/indirector/none'

class Puppet::DataBinding::None < Puppet::Indirector::None
  desc "A Dummy terminus that always returns nil for data lookups."
end
