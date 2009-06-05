# Manage FreeBSD services.
Puppet::Type.type(:service).provide :freebsd, :parent => :init do
    desc "FreeBSD's (and probably NetBSD?) form of ``init``-style service management.

    Uses ``rc.conf.d`` for service enabling and disabling.

"

    confine :operatingsystem => [:freebsd, :netbsd, :openbsd]

    defaultfor :operatingsystem => :freebsd

    @@rcconf_dir = '/etc/rc.conf.d'

    def self.defpath
        superclass.defpath
    end

    # remove service file from rc.conf.d to disable it
    def disable
        rcfile = File.join(@@rcconf_dir, @model[:name])
        if File.exists?(rcfile)
            File.delete(rcfile)
        end
    end

    # if the service file exists in rc.conf.d then it's already enabled
    def enabled?
        rcfile = File.join(@@rcconf_dir, @model[:name])
        if File.exists?(rcfile)
            return :true
        end

        return :false
    end

    # enable service by creating a service file under rc.conf.d with the
    # proper contents
    def enable
        if not File.exists?(@@rcconf_dir)
            Dir.mkdir(@@rcconf_dir)
        end
        rcfile = File.join(@@rcconf_dir, @model[:name])
        open(rcfile, 'w') { |f| f << "%s_enable=\"YES\"\n" % @model[:name] }
    end

    # Override stop/start commands to use one<cmd>'s and the avoid race condition
    # where provider trys to stop/start the service before it is enabled
    def startcmd
        [self.initscript, :onestart]
    end

    def stopcmd
        [self.initscript, :onestop]
    end
end
