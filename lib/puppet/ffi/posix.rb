# frozen_string_literal: true

require 'ffi'

module Puppet
  module FFI
    module POSIX
      require_relative 'posix/functions'
      require_relative 'posix/constants'
    end
  end
end
