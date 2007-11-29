# The standard init-based service type.  Many other service types are
# customizations of this module.
Puppet::Type.type(:service).provide :init, :parent => :base do
    desc "Standard init service management.  This provider assumes that the
        init script has not ``status`` command, because so few scripts do,
        so you need to either provide a status command or specify via ``hasstatus``
        that one already exists in the init script."

    class << self
        attr_accessor :defpath
    end

    case Facter["operatingsystem"].value
    when "FreeBSD":
        @defpath = "/etc/rc.d"
    else
        @defpath = "/etc/init.d"
    end

    # We can't confine this here, because the init path can be overridden.
    #confine :exists => @defpath

    # List all services of this type.
    def self.instances(name)
        # We need to find all paths specified for our type or any parent types
        paths = Puppet.type(:service).paths(name)

        # Now see if there are any included modules
        included_modules.each do |mod|
            next unless mod.respond_to? :name

            mname = mod.name

            if mpaths = Puppet.type(:service).paths(mname) and ! mpaths.empty?
                 paths += mpaths
            end
        end

        paths.collect do |path|
            unless FileTest.directory?(path)
                Puppet.notice "Service path %s does not exist" % path
                next
            end

            check = [:ensure]

            if public_method_defined? :enabled?
                check << :enable
            end

            Dir.entries(path).reject { |e|
                fullpath = File.join(path, e)
                e =~ /^\./ or ! FileTest.executable?(fullpath)
            }.collect do |name|
                new(:name => name, :path => path)
            end
        end
    end

    # Mark that our init script supports 'status' commands.
    def hasstatus=(value)
        case value
        when true, "true": @parameters[:hasstatus] = true
        when false, "false": @parameters[:hasstatus] = false
        else
            raise Puppet::Error, "Invalid 'hasstatus' value %s" %
                value.inspect
        end
    end

    # Where is our init script?
    def initscript
        if defined? @initscript
            return @initscript
        else
            @initscript = self.search(@resource[:name])
        end
    end

    def restart
        if @resource[:hasrestart] == :true
            command = [self.initscript, :restart]
            texecute("restart", command)
        else
            super
        end
    end

    def search(name)
        @resource[:path].each { |path|
            fqname = File.join(path,name)
            begin
                stat = File.stat(fqname)
            rescue
                # should probably rescue specific errors...
                self.debug("Could not find %s in %s" % [name,path])
                next
            end

            # if we've gotten this far, we found a valid script
            return fqname
        }
        @resource[:path].each { |path|
            fqname_sh = File.join(path,"#{name}.sh")
            begin
                stat = File.stat(fqname_sh)
            rescue
                # should probably rescue specific errors...
                self.debug("Could not find %s.sh in %s" % [name,path])
                next
            end

            # if we've gotten this far, we found a valid script
            return fqname_sh
        }
        raise Puppet::Error, "Could not find init script for '%s'" % name
    end

    # The start command is just the init scriptwith 'start'.
    def startcmd
        [self.initscript, :start]
    end

    # If it was specified that the init script has a 'status' command, then
    # we just return that; otherwise, we return false, which causes it to
    # fallback to other mechanisms.
    def statuscmd
        if @resource[:hasstatus]
            return [self.initscript, :status]
        else
            return false
        end
    end

    # The stop command is just the init script with 'stop'.
    def stopcmd
        [self.initscript, :stop]
    end
end

