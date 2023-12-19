# frozen_string_literal: true

require 'ffi'

module Puppet
  module FFI
    module Windows
      require_relative 'windows/api_types'
      require_relative 'windows/constants'
      require_relative 'windows/structs'
      require_relative 'windows/functions'
    end
  end
end
