# Solaris 10 SMF-style services.  This is not yet implemented, which is probably
# somewhat obvious.
Puppet.type(:service).newsvctype(:smf) do
    def restartcmd
        "svcadm restart %s" % self.name
    end

    def startcmd
        "svcadm enable %s" % self.name
    end

    def status
        if self[:status]
            super
            return
        end
        %x{/usr/bin/svcs -l #{self.name} 2>/dev/null}.split("\n").each { |line|
            var = nil
            value = nil
            if line =~ /^(\w+)\s+(.+)/
                var = $1
                value = $2
            else
                Puppet.err "Could not match %s" % line.inspect
            end
            case var
            when "state":
                case value
                when "online":
                    #self.warning "matched running %s" % line.inspect
                    return :running
                when "offline", "disabled":
                    #self.warning "matched stopped %s" % line.inspect
                    return :stopped
                when "legacy_run":
                    raise Puppet::Error,
                        "Cannot manage legacy services through SMF"
                else
                    raise Puppet::Error,
                        "Unmanageable state %s on service %s" %
                        [value, self.name]
                end
            end
        }

        if $? != 0
            raise Puppet::Error,
                "Could not get status on service %s" % self.name
        end
    end

    def stopcmd
        "svcadm disable %s" % self.name
    end
end

# $Id$
