# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :debian, :parent => :init do
    desc "Debian's form of ``init``-style management.  The only difference
        is that this supports service enabling and disabling via ``update-rc.d``."

    commands :update => "/usr/sbin/update-rc.d"
    defaultfor :operatingsystem => :debian

    # Remove the symlinks
    def disable
        cmd = %{#{command(:update)} -f #{@model[:name]} remove 2>&1}
        self.debug "Executing '%s'" % cmd
        output = %x{#{cmd}}

        unless $? == 0
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        cmd = %{#{command(:update)} -n -f #{@model[:name]} remove 2>&1}
        self.debug "Executing 'enabled' test: '%s'" % cmd
        output = %x{#{cmd}}
        unless $? == 0
            raise Puppet::Error, "Could not check %s: %s" %
                [self.name, output]
        end

        # If it's enabled, then it will print output showing removal of
        # links.
        if output =~ /etc\/rc[\dS].d|Nothing to do\./
            return :true
        else
            return :false
        end
    end

    def enable
        cmd = %{#{command(:update)} #{@model[:name]} defaults 2>&1}
        self.debug "Executing '%s'" % cmd
        output = %x{#{cmd}}

        unless $? == 0
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, output]
        end
    end
end

# $Id$
