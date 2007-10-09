# Manage FreeBSD services.
Puppet::Type.type(:service).provide :freebsd, :parent => :init do
    desc "FreeBSD's (and probably NetBSD?) form of ``init``-style service
        management; uses ``rc-update`` for service enabling and disabling."

    commands :rcupdate => "/usr/local/sbin/rc-update"

    defaultfor :operatingsystem => :freebsd

    def self.defpath
        superclass.defpath
    end

    def disable
        begin
            output = rcupdate("disable", @model[:name])
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Could not disable %s: %s" %
                [self.name, output]
        end
    end

    def enabled?
        begin
            output = rcupdate("enabled", @model[:name])
        rescue Puppet::ExecutionFailure
            return :false
        end

        # If it's enabled, output is 0
        if output =~ /^0$/
            return :true
        end

        return :false
    end

    def enable
        begin
            output = rcupdate("enable", @model[:name])
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not enable %s: %s" %
                [self.name, detail]
        end
    end
end
