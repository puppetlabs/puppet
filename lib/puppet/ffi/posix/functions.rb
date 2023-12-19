# frozen_string_literal: true

require_relative '../../../puppet/ffi/posix'

module Puppet::FFI::POSIX
  module Functions
    extend FFI::Library

    ffi_convention :stdcall

    # https://man7.org/linux/man-pages/man3/getgrouplist.3.html
    # int getgrouplist (
    #   const char *user,
    #   gid_t group,
    #   gid_t *groups,
    #   int *ngroups
    # );
    begin
      ffi_lib FFI::Library::LIBC
      attach_function :getgrouplist, [:string, :uint, :pointer, :pointer], :int
    rescue FFI::NotFoundError
      # Do nothing
    end
  end
end
