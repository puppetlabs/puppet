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
    or this can be overriden in the service resource parameters:
    service {
     \"myservice\":
       provider => \"daemontools\", path => \"/path/to/daemons\";
    }

    This provider supports out of the box:
     * start/stop (mapped to enable/disable)
     * enable/disable
     * restart
     * status"

    commands :svc  => "/usr/bin/svc"
    commands :svstat => "/usr/bin/svstat"

    class << self
        attr_writer :defpath
        
        # this is necessary to autodetect a valid resource
        # default path, since there is no standard for such directory.
        def defpath
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
    
    def restartcmd
        [ command(:svc), "-t", self.service]
    end

    # The start command does nothing, service are automatically started
    # when enabled by svscan. But, forces an enable if necessary
    def start
        # to start make sure the sevice is enabled
        self.enable
        # start is then automatic
    end

    def status
        begin
            output = svstat self.service
            return :running if output =~ /\bup\b/
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new( "Could not get status for service %s: %s" % [ resource.ref, detail] )
        end
        return :stopped
    end

    # unfortunately it is not possible
    # to stop without disabling the service
    def stop
        self.disable
    end

    # disable by stopping the service
    # and removing the symlink so that svscan
    # doesn't restart our service behind our back
    def disable
        # should stop the service
        # stop the log subservice if any
        log = File.join(self.service, "log")
        texecute("stop log", [ command(:svc) , '-dx', log] ) if FileTest.directory?(log)
        
        # stop the main resource
        texecute("stop", [command(:svc), '-dx', self.service] )

        # unlink the daemon symlink to disable it
        File.unlink(self.service) if FileTest.symlink?(self.service)
    end

    def enabled?
        FileTest.symlink?(self.service)
    end

    def enable
        File.symlink(self.daemon, self.service) if ! FileTest.symlink?(self.service)
    end
end

