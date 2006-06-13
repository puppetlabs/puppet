require 'puppet/type/service/init'

# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet.type(:service).newsvctype(:redhat, :init) do
    # Remove the symlinks
    def disable
        begin
            output = util_execute("/sbin/chkconfig #{self[:name]} off 2>&1")
            output += util_execute("/sbin/chkconfig --del #{self[:name]} 2>&1")
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        begin
            output = util_execute("/sbin/chkconfig #{self[:name]} 2>&1").chomp
        rescue Puppet::ExecutionFailure
            return :false
        end

        return :true
    end

    # Don't support them specifying runlevels; always use the runlevels
    # in the init scripts.
    def enable
        begin
            output = util_execute("/sbin/chkconfig --add #{self[:name]} 2>&1")
            output += util_execute("/sbin/chkconfig #{self[:name]} on 2>&1")
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, output]
        end
    end
end
