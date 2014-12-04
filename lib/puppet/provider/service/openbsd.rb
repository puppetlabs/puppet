Puppet::Type.type(:service).provide :openbsd, :parent => :init do

  desc "Provider for OpenBSD's rc.d daemon control scripts"

  commands :rcctl => '/usr/sbin/rcctl'

  confine :operatingsystem => :openbsd
  defaultfor :operatingsystem => :openbsd
  has_feature :flaggable

  def startcmd
    [command(:rcctl), '-f', :start, @resource[:name]]
  end

  def stopcmd
    [command(:rcctl), :stop, @resource[:name]]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [command(:rcctl), '-f', :restart, @resource[:name]]
  end

  def statuscmd
    [command(:rcctl), :check, @resource[:name]]
  end

  # @api private
  # When storing the name, take into account not everything has
  # '_flags', like 'multicast_host' and 'pf'.
  def self.instances
    instances = []

    begin
      execpipe([command(:rcctl), :status]) do |process|
        process.each_line do |line|
          match = /^(.*?)(?:_flags)?=(.*)$/.match(line)
          attributes_hash = {
            :name      => match[1],
            :flags     => match[2],
            :hasstatus => true,
            :provider  => :openbsd,
          }

          instances << new(attributes_hash);
        end
      end
      instances
    rescue Puppet::ExecutionFailure
      return nil
    end
  end

  def enabled?
    output = execute([command(:rcctl), "status", @resource[:name]],
                     :failonfail => false, :combine => false, :squelch => false).chomp

    if output == 'NO'
      self.debug("Is disabled")
      return :false
    else
      self.debug("Is enabled")
      return :true
    end
  end

  def enable
    self.debug("Enabling")
    if @resource[:flags]
      rcctl(:enable, @resource[:name], :flags, @resource[:flags])
    else
      rcctl(:enable, @resource[:name])
    end
  end

  def disable
    self.debug("Disabling")
    rcctl(:disable, @resource[:name])
  end

  def running?
    output = execute([command(:rcctl), "check", @resource[:name]],
                     :failonfail => false, :combine => false, :squelch => false).chomp
    return true if output.match(/\(ok\)/)
  end

  # Uses the wrapper to prevent failure when the service is not running;
  # rcctl(8) return non-zero in that case.
  def flags
    output = execute([command(:rcctl), "status", @resource[:name]],
                     :failonfail => false, :combine => false, :squelch => false).chomp
    self.debug("Flags are: #{output}")
    output
  end

  def flags=(value)
    self.debug("Changing flags from #{flags} to #{value}")
    rcctl(:enable, @resource[:name], :flags, value)
    # If the service is already running, force a restart as the flags have been changed.
    rcctl(:restart, @resource[:name]) if running?
  end
end
