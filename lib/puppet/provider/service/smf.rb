# Solaris 10 SMF-style services.
Puppet::Type.type(:service).provide :smf, :parent => :base do
    desc "Support for Sun's new Service Management Framework.

    Starting a service is effectively equivalent to enabling it, so there is
    only support for starting and stopping services, which also enables and
    disables them, respectively.

  "

    defaultfor :operatingsystem => :solaris

    confine :operatingsystem => :solaris

    commands :adm => "/usr/sbin/svcadm", :svcs => "/usr/bin/svcs"

    def enable
        self.start
    end

    def enabled?
        case self.status
        when :running:
            return :true
        else
            return :false
        end
    end

    def disable
        self.stop
    end

    def restartcmd
        [command(:adm), :restart, @resource[:name]]
    end

    def startcmd
        [command(:adm), :enable, @resource[:name]]
    end

    def status
        if @resource[:status]
            super
            return
        end
        begin
            output = svcs "-l", @resource[:name]
        rescue Puppet::ExecutionFailure
            warning "Could not get status on service %s" % self.name
            return :stopped
        end

        output.split("\n").each { |line|
            var = nil
            value = nil
            if line =~ /^(\w+)\s+(.+)/
                var = $1
                value = $2
            else
                Puppet.err "Could not match %s" % line.inspect
                next
            end
            case var
            when "state":
                case value
                when "online":
                    #self.warning "matched running %s" % line.inspect
                    return :running
                when "offline", "disabled", "uninitialized"
                    #self.warning "matched stopped %s" % line.inspect
                    return :stopped
                when "legacy_run":
                    raise Puppet::Error,
                        "Cannot manage legacy services through SMF"
                else
                    raise Puppet::Error,
                        "Unmanageable state '%s' on service %s" %
                        [value, self.name]
                end
            end
        }
    end

    def stopcmd
        [command(:adm), :disable, @resource[:name]]
    end
end

