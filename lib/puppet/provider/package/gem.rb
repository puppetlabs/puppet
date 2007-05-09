# Ruby gems support.
Puppet::Type.type(:package).provide :gem do
    desc "Ruby Gem support.  By default uses remote gems, but you can specify
        the path to a local gem via ``source``."

    commands :gemcmd => "gem"

    def self.gemlist(hash)
        command = [command(:gemcmd), "list"]

        if hash[:local]
            command << "--local"
        else
            command << "--remote"
        end

        if name = hash[:justme]
            command << name
        end

        begin
            list = execute(command).split("\n\n").collect do |set|
                if gemhash = gemsplit(set)
                    gemhash[:provider] = :gem
                    gemhash
                else
                    nil
                end
            end.reject { |p| p.nil? }
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not list gems: %s" % detail
        end

        if hash[:justme]
            return list.shift
        else
            return list
        end
    end

    def self.gemsplit(desc)
        case desc
        when /^\*\*\*/: return nil
        when /^(\S+)\s+\((.+)\)\n/
            name = $1
            version = $2.split(/,\s*/)[0]
            return {
                :name => name,
                :ensure => version
            }
        else
            Puppet.warning "Could not match %s" % desc
            nil
        end
    end

    def self.list(justme = false)
        gemlist(:local => true).collect do |hash|
            Puppet::Type.type(:package).installedpkg(hash)
        end
    end

    def install(useversion = true)
        command = ["install"]
        if (! @resource.should(:ensure).is_a? Symbol) and useversion
            command << "-v" << @resource.should(:ensure)
        end
        # Always include dependencies
        command << "--include-dependencies"

        if source = @resource[:source]
            command << source
        else
            command << @resource[:name]
        end

        gemcmd(*command)
    end

    def latest
        # This always gets the latest version available.
        hash = self.class.gemlist(:justme => @resource[:name])

        return hash[:ensure]
    end

    def query
        self.class.gemlist(:justme => @resource[:name], :local => true)
    end

    def uninstall
        gemcmd "uninstall", "-x", "-a", @resource[:name]
    end

    def update
        self.install(false)
    end

    def versionable?
        true
    end
end

# $Id$
