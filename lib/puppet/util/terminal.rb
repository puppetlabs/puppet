module Puppet::Util::Terminal
  class << self
    # Borrowed shamelessly from Thor, who borrowed this from Rake.
    def width
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
end
