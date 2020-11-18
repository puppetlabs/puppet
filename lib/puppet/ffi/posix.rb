require 'ffi'

module Puppet
  module FFI
    module POSIX
      require 'puppet/ffi/posix/functions'
      require 'puppet/ffi/posix/constants'
    end
  end
end
