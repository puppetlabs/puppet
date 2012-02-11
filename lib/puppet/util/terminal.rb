module Puppet::Util::Terminal
  # Attempts to determine the width of the terminal.  This is currently only
  # supported on POSIX systems, and relies on the claims of `stty` (or `tput`).
  #
  # Inspired by code from Thor; thanks wycats!
  # @return [Number] The column width of the terminal.  Defaults to 80 columns.
  def self.width
    if Puppet.features.posix?
      result = %x{stty size 2>/dev/null}.split[1] ||
               %x{tput cols 2>/dev/null}.split[0] ||
              '80'
    end
    return result.to_i
  rescue
    return 80
  end
end
