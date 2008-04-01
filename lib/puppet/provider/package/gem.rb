require 'puppet/provider/package'

# Ruby gems support.
Puppet::Type.type(:package).provide :gem, :parent => Puppet::Provider::Package do
    desc "Ruby Gem support.  By default uses remote gems, but you can specify
        the path to a local gem via ``source``."

    has_feature :versionable

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
            list = execute(command).split("\n").collect do |set|
                if gemhash = gemsplit(set)
                    gemhash[:provider] = :gem
                    gemhash
                else
                    nil
                end
            end.compact
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
        when /^\*\*\*/, /^\s*$/, /^\s+/; return nil
        when /^(\S+)\s+\((.+)\)/
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

    def self.instances(justme = false)
        gemlist(:local => true).collect do |hash|
            new(hash)
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

        output = gemcmd(*command)
        # Apparently some stupid gem versions don't exit non-0 on failure
        if output.include?("ERROR")
            self.fail "Could not install: %s" % output.chomp
        end
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
end

