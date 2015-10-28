require 'timeout'

# AIX System Resource controller (SRC)
Puppet::Type.type(:service).provide :src, :parent => :base do

  desc "Support for AIX's System Resource controller.

  Services are started/stopped based on the `stopsrc` and `startsrc`
  commands, and some services can be refreshed with `refresh` command.

  Enabling and disabling services is not supported, as it requires
  modifications to `/etc/inittab`. Starting and stopping groups of subsystems
  is not yet supported.
  "

  defaultfor :operatingsystem => :aix
  confine :operatingsystem => :aix

  optional_commands :stopsrc  => "/usr/bin/stopsrc",
                    :startsrc => "/usr/bin/startsrc",
                    :refresh  => "/usr/bin/refresh",
                    :lssrc    => "/usr/bin/lssrc",
                    :lsitab   => "/usr/sbin/lsitab",
                    :mkitab   => "/usr/sbin/mkitab",
                    :rmitab   => "/usr/sbin/rmitab",
                    :chitab   => "/usr/sbin/chitab"

  has_feature :refreshable

  def self.instances
    services = lssrc('-S')
    services.split("\n").reject { |x| x.strip.start_with? '#' }.collect do |line|
      data = line.split(':')
      service_name = data[0]
      new(:name => service_name)
    end
  end

  def startcmd
    [command(:startsrc), "-s", @resource[:name]]
  end

  def stopcmd
    [command(:stopsrc), "-s", @resource[:name]]
  end

  def default_runlevel
    "2"
  end

  def default_action
    "once"
  end

  def enabled?
    execute([command(:lsitab), @resource[:name]], {:failonfail => false, :combine => true})
    $CHILD_STATUS.exitstatus == 0 ? :true : :false
  end

  def enable
    mkitab("%s:%s:%s:%s" % [@resource[:name], default_runlevel, default_action, startcmd.join(" ")])
  end

  def disable
    rmitab(@resource[:name])
  end

  # Wait for the service to transition into the specified state before returning.
  # This is necessary due to the asynchronous nature of AIX services.
  # desired_state should either be :running or :stopped.
  def wait(desired_state)
    Timeout.timeout(60) do
      loop do
        status = self.status
        break if status == desired_state.to_sym
        sleep(1)
      end
    end
  rescue Timeout::Error
    raise Puppet::Error.new("Timed out waiting for #{@resource[:name]} to transition states")
  end

  def start
    super
    self.wait(:running)
  end

  def stop
    super
    self.wait(:stopped)
  end

  def restart
      execute([command(:lssrc), "-Ss", @resource[:name]]).each_line do |line|
        args = line.split(":")

        next unless args[0] == @resource[:name]

        # Subsystems with the -K flag can get refreshed (HUPed)
        # While subsystems with -S (signals) must be stopped/started
        method = args[11]
        do_refresh = case method
          when "-K" then :true
          when "-S" then :false
          else self.fail("Unknown service communication method #{method}")
        end

        begin
          if do_refresh == :true
            execute([command(:refresh), "-s", @resource[:name]])
          else
            self.stop
            self.start
          end
          return :true
        rescue Puppet::ExecutionFailure => detail
          raise Puppet::Error.new("Unable to restart service #{@resource[:name]}, error was: #{detail}", detail )
        end
      end
      self.fail("No such service found")
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new("Cannot get status of #{@resource[:name]}, error was: #{detail}", detail )
  end

  def status
      execute([command(:lssrc), "-s", @resource[:name]]).each_line do |line|
        args = line.split

        # This is the header line
        next unless args[0] == @resource[:name]

        # PID is the 3rd field, but inoperative subsystems
        # skip this so split doesn't work right
        state = case args[-1]
          when "active" then :running
          when "inoperative" then :stopped
        end
        Puppet.debug("Service #{@resource[:name]} is #{args[-1]}")
        return state
      end
      self.fail("No such service found")
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new("Cannot get status of #{@resource[:name]}, error was: #{detail}", detail )
  end

end

