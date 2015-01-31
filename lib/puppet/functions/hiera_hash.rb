require 'puppet/functions/hiera_common'

Puppet::Functions.create_function(:hiera_hash, Puppet::Functions::InternalFunction, &Puppet::Functions::HieraCommon.common_layout)
