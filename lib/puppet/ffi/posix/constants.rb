# frozen_string_literal: true

require_relative '../../../puppet/ffi/posix'

module Puppet::FFI::POSIX
  module Constants
    extend FFI::Library

    # Maximum number of supplementary groups (groups
    # that a user can be in plus its primary group)
    # (64 + 1 primary group)
    # Chosen a reasonable middle number from the list
    # https://www.j3e.de/ngroups.html
    MAXIMUM_NUMBER_OF_GROUPS = 65
  end
end
