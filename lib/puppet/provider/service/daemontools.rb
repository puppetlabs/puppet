# Daemontools service management
#
# author Brice Figureau <brice-puppet@daysofwonder.com>
Puppet::Type.type(:service).provide :daemontools, :parent => :base do
  desc <<-'EOT'
    Daemontools service management.

    This provider manages daemons supervised by D.J. Bernstein daemontools.
    When detecting the service directory it will check, in order of preference:

    * `/service`
    * `/etc/service`
    * `/var/lib/svscan`

    The daemon directory should be in one of the following locations:

    * `/var/lib/service`
    * `/etc`

    ...or this can be overriden in the resource's attributes:

        service { "myservice":
          provider => "daemontools",
          path     => "/path/to/daemons",
        }

    This provider supports out of the box:

    * start/stop (mapped to enable/disable)
    * enable/disable
    * restart
    * status

    If a service has `ensure => "running"`, it will link /path/to/daemon to
    /path/to/service, which will automatically enable the service.

    If a service has `ensure => "stopped"`, it will only shut down the service, not
    remove the `/path/to/service` link.

  EOT

  commands :svc  => "/usr/bin/svc", :svstat => "/usr/bin/svstat"

  class << self
    attr_writer :defpath

    # Determine the daemon path.
    def defpath(dummy_argument=:work_arround_for_ruby_GC_bug)
      unless @defpath
        ["/var/lib/service", "/etc"].each do |path|
          if Puppet::FileSystem.exist?(path)
            @defpath = path
            break
          end
        end
        raise "Could not find the daemon directory (tested [/var/lib/service,/etc])" unless @defpath
      end
      @defpath
    end
  end

  attr_writer :servicedir

  # returns all providers for all existing services in @defpath
  # ie enabled or not
  def self.instances
    path = defpath
    unless FileTest.directory?(path)
      Puppet.notice "Service path #{path} does not exist"
      return
    end

    # reject entries that aren't either a directory
    # or don't contain a run file
    Dir.entries(path).reject { |e|
      fullpath = File.join(path, e)
      e =~ /^\./ or ! FileTest.directory?(fullpath) or ! Puppet::FileSystem.exist?(File.join(fullpath,"run"))
    }.collect do |name|
      new(:name => name, :path => path)
    end
  end

  # returns the daemon dir on this node
  def self.daemondir
    defpath
  end

  # find the service dir on this node
  def servicedir
    unless @servicedir
      ["/service", "/etc/service","/var/lib/svscan"].each do |path|
        if Puppet::FileSystem.exist?(path)
          @servicedir = path
          break
        end
      end
      raise "Could not find service directory" unless @servicedir
    end
    @servicedir
  end

  # returns the full path of this service when enabled
  # (ie in the service directory)
  def service
    File.join(servicedir, resource[:name])
  end

  # returns the full path to the current daemon directory
  # note that this path can be overriden in the resource
  # definition
  def daemon
    File.join(resource[:path], resource[:name])
  end

  def status
    begin
      output = svstat service
      if output =~ /:\s+up \(/
        return :running
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new( "Could not get status for service #{resource.ref}: #{detail}", detail)
    end
    :stopped
  end

  def setupservice
      if resource[:manifest]
        Puppet.notice "Configuring #{resource[:name]}"
        command = [ resource[:manifest], resource[:name] ]
        #texecute("setupservice", command)
        system("#{command}")
      end
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new( "Cannot config #{service} to enable it: #{detail}", detail)
  end

  def enabled?
    case status
    when :running
      # obviously if the daemon is running then it is enabled
      return :true
    else
      # the service is enabled if it is linked
      return Puppet::FileSystem.symlink?(service) ? :true : :false
    end
  end

  def enable
    unless FileTest.directory?(daemon)
      Puppet.notice "No daemon dir, calling setupservice for #{resource[:name]}"
      setupservice
    end
    if daemon
      unless Puppet::FileSystem.symlink?(service)
        Puppet.notice "Enabling #{service}: linking #{daemon} -> #{service}"
        Puppet::FileSystem.symlink(daemon, service)
      end
    end
rescue Puppet::ExecutionFailure
    raise Puppet::Error.new( "No daemon directory found for #{service}", $!)
  end

  def disable
    begin
      unless FileTest.directory?(daemon)
        Puppet.notice "No daemon dir, calling setupservice for #{resource[:name]}"
        setupservice
      end
      if daemon
        if Puppet::FileSystem.symlink?(service)
          Puppet.notice "Disabling #{service}: removing link #{daemon} -> #{service}"
          Puppet::FileSystem.unlink(service)
        end
      end
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new( "No daemon directory found for #{service}", $!)
    end
    stop
  end

  def restart
    svc "-t", service
  end

  def start
    enable unless enabled? == :true
    svc "-u", service
  end

  def stop
    svc "-d", service
  end
end
