# Ruby gems support.
Puppet::Type.type(:package).provide :gem do
    desc "Ruby Gem support.  By default uses remote gems, but you can specify
        the path to a local gem via ``source``."

    commands :gem => "gem"

    def self.gemlist(hash)
        command = "#{command(:gem)} list "

        if hash[:local]
            command += "--local "
        else
            command += "--remote "
        end

        if name = hash[:justme]
            command += name
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
        gemlist(:local => true).each do |hash|
            Puppet::Type.type(:package).installedpkg(hash)
        end
    end

    def install(useversion = true)
        command = "install "
        if (! @model.should(:ensure).is_a? Symbol) and useversion
            command += "-v %s " % @model.should(:ensure)
        end
        if source = @model[:source]
            command += source
        else
            command += @model[:name]
        end

        gem command
    end

    def latest
        # This always gets the latest version available.
        hash = self.class.gemlist(:justme => @model[:name])

        return hash[:ensure]
    end

    def query
        self.class.gemlist(:justme => @model[:name], :local => true)
    end

    def uninstall
        gem "uninstall -x -a #{@model[:name]}"
    end

    def update
        self.install(false)
    end

    def versionable?
        true
    end
end

# $Id$
