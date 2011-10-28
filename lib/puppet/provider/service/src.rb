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

  commands :stopsrc  => "/usr/bin/stopsrc"
  commands :startsrc => "/usr/bin/startsrc"
  commands :refresh  => "/usr/bin/refresh"
  commands :lssrc    => "/usr/bin/lssrc"

  has_feature :refreshable

  def startcmd
    [command(:startsrc), "-s", @resource[:name]]
  end

  def stopcmd
    [command(:stopsrc), "-s", @resource[:name]]
  end

  def restart
      execute([command(:lssrc), "-Ss", @resource[:name]]).each do |line|
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
          raise Puppet::Error.new("Unable to restart service #{@resource[:name]}, error was: #{detail}" )
        end
      end
      self.fail("No such service found")
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new("Cannot get status of #{@resource[:name]}, error was: #{detail}" )
  end

  def status
      execute([command(:lssrc), "-s", @resource[:name]]).each do |line|
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
      raise Puppet::Error.new("Cannot get status of #{@resource[:name]}, error was: #{detail}" )
  end

end

