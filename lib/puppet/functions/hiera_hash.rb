require 'puppet/functions/hiera_function'

Puppet::Functions.create_function(:hiera_hash, Puppet::Functions::InternalFunction, &Puppet::Functions::HieraFunction.common_layout)
