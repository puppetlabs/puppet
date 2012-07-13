module Puppet::Util::ConfigTimeout
  # NOTE: in the future it might be a good idea to add an explicit "integer" type to
  #  the settings types, in which case this would no longer be necessary.

  # Get the value of puppet's "configtimeout" setting, as an integer.  Raise an
  # ArgumentError if the setting does not contain a valid integer value.
  # @return Puppet config timeout setting value, as an integer
  def timeout_interval
    timeout = Puppet[:configtimeout]
    case timeout
    when String
      if timeout =~ /^\d+$/
        timeout = Integer(timeout)
      else
        raise ArgumentError, "Configuration timeout must be an integer"
      end
    when Integer # nothing
    else
      raise ArgumentError, "Configuration timeout must be an integer"
    end

    timeout
  end
end
