require 'puppet/provider/package'
require 'uri'

# Ruby gems support.
Puppet::Type.type(:package).provide :gem, :parent => Puppet::Provider::Package do
    desc "Ruby Gem support.  If a URL is passed via ``source``, then that URL is used as the
         remote gem repository; if a source is present but is not a valid URL, it will be
         interpreted as the path to a local gem file.  If source is not present at all,
         the gem will be installed from the default gem repositories."

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
        command = [command(:gemcmd), "install"]
        if (! resource[:ensure].is_a? Symbol) and useversion
            command << "-v" << resource[:ensure]
        end
        # Always include dependencies
        command << "--include-dependencies"

        if source = resource[:source]
            begin
                uri = URI.parse(source)
            rescue => detail
                fail "Invalid source '%s': %s" % [uri, detail]
            end

            case uri.scheme
            when nil
                # no URI scheme => interpret the source as a local file
                command << source
            when /file/i
                command << uri.path
            when 'puppet'
                # we don't support puppet:// URLs (yet)
                raise Puppet::Error.new("puppet:// URLs are not supported as gem sources")
            else
                # interpret it as a gem repository
                command << "--source" << "#{source}" << resource[:name]
            end
        else
            command << resource[:name]
        end

        output = execute(command)
        # Apparently some stupid gem versions don't exit non-0 on failure
        if output.include?("ERROR")
            self.fail "Could not install: %s" % output.chomp
        end
    end

    def latest
        # This always gets the latest version available.
        hash = self.class.gemlist(:justme => resource[:name])

        return hash[:ensure]
    end

    def query
        self.class.gemlist(:justme => resource[:name], :local => true)
    end

    def uninstall
        gemcmd "uninstall", "-x", "-a", resource[:name]
    end

    def update
        self.install(false)
    end
end

