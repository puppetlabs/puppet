require 'ffi'

module Puppet
  module FFI
    module Windows
      require_relative '../../puppet/ffi/windows/api_types'
      require_relative '../../puppet/ffi/windows/constants'
      require_relative '../../puppet/ffi/windows/structs'
      require_relative '../../puppet/ffi/windows/functions'
    end
  end
end
