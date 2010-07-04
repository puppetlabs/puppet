# Daemontools service management
#
# author Brice Figureau <brice-puppet@daysofwonder.com>
Puppet::Type.type(:service).provide :daemontools, :parent => :base do
    desc "Daemontools service management.

    This provider manages daemons running supervised by D.J.Bernstein daemontools.
    It tries to detect the service directory, with by order of preference:

    * /service
    * /etc/service
    * /var/lib/svscan

    The daemon directory should be placed in a directory that can be
    by default in:

    * /var/lib/service
    * /etc

    or this can be overriden in the service resource parameters::

      service {
       \"myservice\":
         provider => \"daemontools\", path => \"/path/to/daemons\";
      }

    This provider supports out of the box:

    * start/stop (mapped to enable/disable)
    * enable/disable
    * restart
    * status

    If a service has ensure => \"running\", it will link /path/to/daemon to
    /path/to/service, which will automatically enable the service.

    If a service has ensure => \"stopped\", it will only down the service, not
    remove the /path/to/service link.

    "

    commands :svc  => "/usr/bin/svc", :svstat => "/usr/bin/svstat"

    class << self
        attr_writer :defpath

        # Determine the daemon path.
        def defpath(dummy_argument=:work_arround_for_ruby_GC_bug)
            unless defined?(@defpath) and @defpath
                ["/var/lib/service", "/etc"].each do |path|
                    if FileTest.exist?(path)
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
        path = self.defpath
        unless FileTest.directory?(path)
            Puppet.notice "Service path %s does not exist" % path
            next
        end

        # reject entries that aren't either a directory
        # or don't contain a run file
        Dir.entries(path).reject { |e|
            fullpath = File.join(path, e)
            e =~ /^\./ or ! FileTest.directory?(fullpath) or ! FileTest.exist?(File.join(fullpath,"run"))
        }.collect do |name|
            new(:name => name, :path => path)
        end
    end

    # returns the daemon dir on this node
    def self.daemondir
        self.defpath
    end

    # find the service dir on this node
    def servicedir
        unless defined?(@servicedir) and @servicedir
            ["/service", "/etc/service","/var/lib/svscan"].each do |path|
                if FileTest.exist?(path)
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
        File.join(self.servicedir, resource[:name])
    end

    # returns the full path to the current daemon directory
    # note that this path can be overriden in the resource
    # definition
    def daemon
        File.join(resource[:path], resource[:name])
    end

    def status
        begin
            output = svstat self.service
            if output =~ /:\s+up \(/
                return :running
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new( "Could not get status for service %s: %s" % [ resource.ref, detail] )
        end
        return :stopped
    end

    def setupservice
        begin
            if resource[:manifest]
                Puppet.notice "Configuring %s" % resource[:name]
                command = [ resource[:manifest], resource[:name] ]
                #texecute("setupservice", command)
                rv = system("#{command}")
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new( "Cannot config %s to enable it: %s" % [ self.service, detail ] )
        end
    end

    def enabled?
        case self.status
        when :running
            # obviously if the daemon is running then it is enabled
            return :true
        else
            # the service is enabled if it is linked
            return FileTest.symlink?(self.service) ? :true : :false
        end
    end

    def enable
        begin
            if ! FileTest.directory?(self.daemon)
                Puppet.notice "No daemon dir, calling setupservice for %s" % resource[:name]
                self.setupservice
            end
            if self.daemon
                if ! FileTest.symlink?(self.service)
                    Puppet.notice "Enabling %s: linking %s -> %s" % [ self.service, self.daemon, self.service ]
                    File.symlink(self.daemon, self.service)
                end
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new( "No daemon directory found for %s" % self.service )
        end
    end

    def disable
        begin
            if ! FileTest.directory?(self.daemon)
                Puppet.notice "No daemon dir, calling setupservice for %s" % resource[:name]
                self.setupservice
            end
            if self.daemon
                if FileTest.symlink?(self.service)
                    Puppet.notice "Disabling %s: removing link %s -> %s" % [ self.service, self.daemon, self.service ]
                    File.unlink(self.service)
                end
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new( "No daemon directory found for %s" % self.service )
        end
        self.stop
    end

    def restart
        svc "-t", self.service
    end

    def start
        enable unless enabled? == :true
        svc "-u", self.service
    end

    def stop
        svc "-d", self.service
    end
end
