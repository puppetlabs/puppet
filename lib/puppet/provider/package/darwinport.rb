Puppet::Type.type(:package).provide :darwinport do
    desc "Package management using DarwinPorts on OS X."

    PORT = "/opt/local/bin/port"
    confine :exists => PORT, :operatingsystem => "Darwin"

    def self.eachpkgashash
        # list out all of the packages
        open("| #{PORT} list installed") { |process|
            regex = %r{(\S+)\s+@(\S+)\s+(\S+)}
            fields = [:name, :ensure, :location]
            hash = {}

            # now turn each returned line into a package object
            process.each { |line|
                hash.clear

                if match = regex.match(line)
                    fields.zip(match.captures) { |field,value|
                        hash[field] = value
                    }

                    hash.delete :location
                    yield hash.dup
                else
                    raise Puppet::DevError,
                        "Failed to match dpkg line %s" % line
                end
            }
        }
    end

    def self.list
        packages = []

        eachpkgashash do |hash|
            pkg = Puppet.type(:package).installedpkg(hash)
            packages << pkg
        end

        return packages
    end

    def install
        should = @model[:ensure]

        # Seems like you can always say 'upgrade'
        cmd = "#{PORT} upgrade #{@model[:name]}"

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
    end

    def query
        version = nil
        self.class.eachpkgashash do |hash|
            if hash[:name] == @model[:name]
                return hash
            end
        end

        return nil
    end

    def latest
        info = %x{#{PORT} search '^#{@model[:name]}$' 2>/dev/null}

        if $? != 0 or info =~ /^Error/
            return nil
        end

        ary = info.split(/\s+/)
        version = ary[2].sub(/^@/, '')

        return version
    end

    def uninstall
        cmd = "#{PORT} uninstall #{@model[:name]}"
        output = %x{#{cmd} 2>&1}
        if $? != 0
            raise Puppet::PackageError.new(output)
        end
    end

    def update
        return install()
    end
end

# $Id$
