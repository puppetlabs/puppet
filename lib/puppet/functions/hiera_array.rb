require 'puppet/functions/hiera_common.rb'

Puppet::Functions.create_function(:hiera_array, Puppet::Functions::InternalFunction, &Puppet::Functions::HieraCommon.common_layout)
