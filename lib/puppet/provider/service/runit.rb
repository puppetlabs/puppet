# Daemontools service management
#
# author Brice Figureau <brice-puppet@daysofwonder.com>
Puppet::Type.type(:service).provide :runit, :parent => :daemontools do
  desc <<-'EOT'
    Runit service management.

    This provider manages daemons running supervised by Runit.
    When detecting the service directory it will check, in order of preference:

    * `/service`
    * `/etc/service`
    * `/var/service`

    The daemon directory should be in one of the following locations:

    * `/etc/sv`
    * `/var/lib/service`

    or this can be overridden in the service resource parameters:

        service { 'myservice':
          provider => 'runit',
          path     => '/path/to/daemons',
        }

    This provider supports out of the box:

    * start/stop
    * enable/disable
    * restart
    * status


  EOT

  commands :sv => "/usr/bin/sv"

  class << self
    # this is necessary to autodetect a valid resource
    # default path, since there is no standard for such directory.
    def defpath
      unless @defpath
        ["/etc/sv", "/var/lib/service"].each do |path|
          if Puppet::FileSystem.exist?(path)
            @defpath = path
            break
          end
        end
        raise "Could not find the daemon directory (tested [/etc/sv,/var/lib/service])" unless @defpath
      end
      @defpath
    end
  end

  # find the service dir on this node
  def servicedir
    unless @servicedir
      ["/service", "/etc/service","/var/service"].each do |path|
        if Puppet::FileSystem.exist?(path)
          @servicedir = path
          break
        end
      end
      raise "Could not find service directory" unless @servicedir
    end
    @servicedir
  end

  def status
    begin
      output = sv "status", self.daemon
      return :running if output =~ /^run: /
    rescue Puppet::ExecutionFailure => detail
      unless detail.message =~ /(warning: |runsv not running$)/
        raise Puppet::Error.new( "Could not get status for service #{resource.ref}: #{detail}", detail )
      end
    end
    :stopped
  end

  def stop
    sv "stop", self.service
  end

  def start
    if enabled? != :true
        enable
        # Work around issue #4480
        # runsvdir takes up to 5 seconds to recognize
        # the symlink created by this call to enable
        #TRANSLATORS 'runsvdir' is a linux service name and should not be translated
        Puppet.info _("Waiting 5 seconds for runsvdir to discover service %{service}") % { service: self.service }
        sleep 5
    end
    sv "start", self.service
  end

  def restart
    sv "restart", self.service
  end

  # disable by removing the symlink so that runit
  # doesn't restart our service behind our back
  # note that runit doesn't need to perform a stop
  # before a disable
  def disable
    # unlink the daemon symlink to disable it
    Puppet::FileSystem.unlink(self.service) if Puppet::FileSystem.symlink?(self.service)
  end
end

