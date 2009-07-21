require 'puppet/provider/package'

Puppet::Type.type(:package).provide :darwinport, :parent => Puppet::Provider::Package do
    desc "Package management using DarwinPorts on OS X."

    confine :operatingsystem => :darwin
    commands :port => "/opt/local/bin/port"

    def self.eachpkgashash
        # list out all of the packages
        open("| #{command(:port)} list installed") { |process|
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
                    hash[:provider] = self.name
                    yield hash.dup
                else
                    raise Puppet::DevError,
                        "Failed to match dpkg line %s" % line
                end
            }
        }
    end

    def self.instances
        packages = []

        eachpkgashash do |hash|
            packages << new(hash)
        end

        return packages
    end

    def install
        should = @resource.should(:ensure)

        # Seems like you can always say 'upgrade'
        output = port "upgrade", @resource[:name]
        if output =~ /^Error: No port/
            raise Puppet::ExecutionFailure, "Could not find package %s" % @resource[:name]
        end
    end

    def query
        version = nil
        self.class.eachpkgashash do |hash|
            if hash[:name] == @resource[:name]
                return hash
            end
        end

        return nil
    end

    def latest
        info = port :search, "^#{@resource[:name]}$"

        if $? != 0 or info =~ /^Error/
            return nil
        end

        ary = info.split(/\s+/)
        version = ary[2].sub(/^@/, '')

        return version
    end

    def uninstall
        port :uninstall, @resource[:name]
    end

    def update
        return install()
    end
end

