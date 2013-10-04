# The Hiera2 Module contains the classes needed to configure a bindings producer
# to read module specific data. The configuration is expected to be found in
# a hiera.yaml file in the root of each module
module Puppet::Pops::Binder::Hiera2
  require 'puppet/pops/binder/hiera2/config_checker'
  require 'puppet/pops/binder/hiera2/config'
  require 'puppet/pops/binder/hiera2/diagnostic_producer'
  require 'puppet/pops/binder/hiera2/bindings_provider'
  require 'puppet/pops/binder/hiera2/issues'
end
