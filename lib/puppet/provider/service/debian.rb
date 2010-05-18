# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :debian, :parent => :init do
    desc "Debian's form of ``init``-style management.

    The only difference is that this supports service enabling and disabling
    via ``update-rc.d`` and determines enabled status via ``invoke-rc.d``.

    "

    commands :update_rc => "/usr/sbin/update-rc.d"
    # note this isn't being used as a command until
    # http://projects.puppetlabs.com/issues/2538
    # is resolved.
    commands :invoke_rc => "/usr/sbin/invoke-rc.d"
    
    defaultfor :operatingsystem => [:debian, :ubuntu]

    def self.defpath
        superclass.defpath
    end

    # Remove the symlinks
    def disable
        update_rc "-f", @resource[:name], "remove"
        update_rc @resource[:name], "stop", "00", "1", "2", "3", "4", "5", "6", "."
    end

    def enabled?
        # TODO: Replace system() call when Puppet::Util.execute gives us a way
        # to determine exit status.  http://projects.puppetlabs.com/issues/2538
        system("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start")
        
        # 104 is the exit status when you query start an enabled service.
        # 106 is the exit status when the policy layer supplies a fallback action
        # See x-man-page://invoke-rc.d
        if [104, 106].include?($?.exitstatus)
            return :true
        else
            return :false
        end
    end

    def enable
        update_rc "-f", @resource[:name], "remove"
        update_rc @resource[:name], "defaults"
    end
end
