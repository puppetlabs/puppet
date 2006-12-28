# Manage gentoo services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :gentoo, :parent => :init do
    desc "Gentoo's form of ``init``-style service
        management; uses ``rc-update`` for service enabling and disabling."

    commands :update => "/sbin/rc-update"

    defaultfor :operatingsystem => :gentoo

    def disable
        begin
            output = update :del, @model[:name], :default
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        begin
            output = update :show
        rescue Puppet::ExecutionFailure
            return :false
        end

        line = output.split(/\n/).find { |l| l.include?(@model[:name]) }

        return :false unless line

        # If it's enabled then it will print output showing service | runlevel
        if output =~ /#{@model[:name]}\s*|\s*default/
            return :true
        else
            return :false
        end
    end

    def enable
        begin
            output = update :add, @model[:name], :default
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, output]
        end
    end
end

# $Id $
