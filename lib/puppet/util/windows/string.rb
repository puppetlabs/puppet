require 'puppet/util/windows'

module Puppet::Util::Windows::String
  def wide_string(str)
    # bug in win32-api, see https://tickets.puppetlabs.com/browse/PUP-1389
    wstr = str.encode('UTF-16LE')
    wstr << 0
    wstr.strip
  end
  module_function :wide_string
end
