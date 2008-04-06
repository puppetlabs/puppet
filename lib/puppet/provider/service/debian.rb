# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :debian, :parent => :init do
    desc "Debian's form of ``init``-style management.  The only difference
        is that this supports service enabling and disabling via ``update-rc.d``."

    commands :update => "/usr/sbin/update-rc.d"
    defaultfor :operatingsystem => :debian

    def self.defpath
        superclass.defpath
    end

    # Remove the symlinks
    def disable
        update "-f", @resource[:name], "remove"
        update @resource[:name], "stop", "00", "1", "2", "3", "4", "5", "6", "."
    end

    def enabled?
        output = update "-n", "-f", @resource[:name], "remove"

        # If it's enabled, then it will print output showing removal of
        # links.
        if output =~ /etc\/rc[\dS].d\/S|not installed/
            return :true
        else
            return :false
        end
    end

    def enable
        update "-f", @resource[:name], "remove"
        update @resource[:name], "defaults"
    end
end
