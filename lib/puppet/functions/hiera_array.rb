require 'puppet/functions/hiera_function.rb'

Puppet::Functions.create_function(:hiera_array, Puppet::Functions::InternalFunction, &Puppet::Functions::HieraFunction.common_layout)
