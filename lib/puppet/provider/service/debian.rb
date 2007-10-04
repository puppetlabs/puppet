# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :debian, :parent => :init do
    desc "Debian's form of ``init``-style management.  The only difference
        is that this supports service enabling and disabling via ``update-rc.d``."

    commands :update => "/usr/sbin/update-rc.d"
    defaultfor :operatingsystem => :debian

    # Remove the symlinks
    def disable
        update "-f", @resource[:name], "remove"
    end

    def enabled?
        output = update "-n", "-f", @resource[:name], "remove"

        # If it's enabled, then it will print output showing removal of
        # links.
        if output =~ /etc\/rc[\dS].d|Nothing to do\./
            return :true
        else
            return :false
        end
    end

    def enable
        update @resource[:name], "defaults"
    end
end

