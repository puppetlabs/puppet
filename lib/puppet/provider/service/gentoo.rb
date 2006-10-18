# Manage gentoo services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :gentoo, :parent => :init do
    desc "Gentoo's form of ``init``-style service
        management; uses ``rc-update`` for service enabling and disabling."

    commands :update => "/sbin/rc-update"

    defaultfor :operatingsystem => :gentoo

    def disable
        begin
            output = util_execute("#{command(:update)} del #{@model[:name]} default 2>&1")
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        begin
            output = util_execute("#{command(:update)} show | grep #{@model[:name]}").chomp
        rescue Puppet::ExecutionFailure
            return :false
        end

        # If it's enabled then it will print output showing service | runlevel
        if output =~ /#{@model[:name]}\s*|\s*default/
            return :true
        else
            return :false
        end
    end

    def enable
        begin
            output = util_execute("#{command(:update)} add #{@model[:name]} default 2>&1")
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, output]
        end
    end
end

# $Id $
