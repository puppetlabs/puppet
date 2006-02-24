require 'puppet/type/service/init'

# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet.type(:service).newsvctype(:redhat, :init) do
    # Remove the symlinks
    def disable
        output = %x{chkconfig #{self[:name]} off 2>&1}

        unless $? == 0
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        output = %x{chkconfig #{self[:name]} 2>&1}.chomp
        if $? == 0
            return :true
        else
            return :false
        end
    end

    # Don't support them specifying runlevels; always use the runlevels
    # in the init scripts.
    def enable
        output = %x{chkconfig #{self[:name]} on 2>&1}

        unless $? == 0
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, output]
        end
    end
end
