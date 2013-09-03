module Puppet::Util::Signals
  # Return a boolean representing whether or not SIGINFO is supported
  def siginfo_available?
    @siginfo_available ||= Signal.list.has_key?("INFO")
  end
end
