require 'puppet/util/windows'

module Puppet::Util::Windows::String
  def wide_string(str)
    # if given a nil string, assume caller wants to pass a nil pointer to win32
    return nil if str.nil?
    # ruby (< 2.1) does not respect multibyte terminators, so it is possible
    # for a string to contain a single trailing null byte, followed by garbage
    # causing buffer overruns.
    #
    # See http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?revision=41920&view=revision
    newstr = str + "\0".encode(str.encoding)
    newstr.encode!('UTF-16LE')
  end
  module_function :wide_string
end
