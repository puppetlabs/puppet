require 'ffi'

module Puppet
  module FFI
    module Windows
      require 'puppet/ffi/windows/api_types'
      require 'puppet/ffi/windows/constants'
      require 'puppet/ffi/windows/structs'
      require 'puppet/ffi/windows/functions'
    end
  end
end
