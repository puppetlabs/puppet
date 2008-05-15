# Manage Red Hat services.  Start/stop uses /sbin/service and enable/disable uses chkconfig

Puppet::Type.type(:service).provide :redhat, :parent => :init do
    desc "Red Hat's (and probably many others) form of ``init``-style service
        management; uses ``chkconfig`` for service enabling and disabling."

    commands :chkconfig => "/sbin/chkconfig", :service => "/sbin/service"
 
    defaultfor :operatingsystem => [:redhat, :fedora, :suse, :centos]

    def self.defpath
        superclass.defpath
    end

    # Remove the symlinks
    def disable
        begin
            output = chkconfig(@resource[:name], :off)
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        begin
            output = chkconfig(@resource[:name])
        rescue Puppet::ExecutionFailure
            return :false
        end

        # If it's disabled on SuSE, then it will print output showing "off"
        # at the end
        if output =~ /.* off$/
            return :false
        end
	
        return :true
    end

    # Don't support them specifying runlevels; always use the runlevels
    # in the init scripts.
    def enable
        begin
            output = chkconfig(@resource[:name], :on)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, detail]
        end
    end
 
    def restart
        if @resource[:hasrestart] == true
              service(@resource[:name], "restart")
        else
           return false
        end
    end

    def start
        service(@resource[:name], "start")
    end

    def stop
        service(@resource[:name], "stop")
    end

end

