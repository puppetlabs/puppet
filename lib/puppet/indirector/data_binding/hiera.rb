require 'puppet/indirector/hiera'
require 'hiera/scope'

class Puppet::DataBinding::Hiera < Puppet::Indirector::Hiera
  desc "Retrieve data using Hiera."
end

