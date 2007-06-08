require 'puppet/provider/package'

Puppet::Type.type(:package).provide :dpkg, :parent => Puppet::Provider::Package do
    desc "Package management via ``dpkg``.  Because this only uses ``dpkg``
        and not ``apt``, you must specify the source of any packages you want
        to manage."

    commands :dpkg => "/usr/bin/dpkg"
    commands :dpkgquery => "/usr/bin/dpkg-query"
    
    def self.instances
        packages = []

        # list out all of the packages
        cmd = "#{command(:dpkgquery)} -W --showformat '${Status} ${Package} ${Version}\\n'"
        Puppet.debug "Executing '%s'" % cmd
        execpipe(cmd) do |process|
            # our regex for matching dpkg output
            regex = %r{^(\S+ +\S+ +\S+) (\S+) (\S*)$}
            fields = [:status, :name, :ensure]
            hash = {}

            # now turn each returned line into a package object
            process.each { |line|
                if match = regex.match(line)
                    hash.clear

                    fields.zip(match.captures) { |field,value|
                        hash[field] = value
                    }

                    hash[:provider] = self.name

                    packages << new(hash)
                else
                    Puppet.warning "Failed to match dpkg-query line %s" %
                        line.inspect
                end
            }
        end

        return packages
    end

    def install
        unless file = @resource[:source]
            raise ArgumentError, "You cannot install dpkg packages without a source"
        end
        dpkg "-i", file
    end

    def query
        packages = []

        fields = [:desired, :error, :status, :name, :ensure]

        hash = {}

        # list out our specific package
        begin
            output = dpkgquery("-W", "--showformat",
                '${Status} ${Package} ${Version}\\n', @resource[:name]
            )
        rescue Puppet::ExecutionFailure
            # dpkg-query exits 1 if the package is not found.
            return {:ensure => :purged, :status => 'missing',
                :name => @resource[:name], :error => 'ok'}

        end
        # Our regex for matching dpkg-query output.  We could probably just
        # use split here, but I'm not positive that dpkg-query will never
        # return whitespace.
        regex = %r{^(\S+) (\S+) (\S+) (\S+) (\S*)$}

        line = output.split("\n").shift.chomp
        
        if match = regex.match(line)
            fields.zip(match.captures) { |field,value|
                hash[field] = value
            }
        else
            notice "Failed to handle dpkg-query line %s" % line.inspect
            return {:ensure => :absent, :status => 'missing',
                :name => @resource[:name], :error => 'ok'}
        end

        if hash[:error] != "ok"
            raise Puppet::PackageError.new(
                "Package %s, version %s is in error state: %s" %
                    [hash[:name], hash[:ensure], hash[:error]]
            )
        end

        # DPKG can discuss packages that are no longer installed, so allow that.
        if hash[:status] != "installed"
            hash[:ensure] = :absent
        end

        return hash
    end

    def uninstall
        dpkg "-r", @resource[:name]
    end

    def purge
        dpkg "--purge", @resource[:name]
    end
end

# $Id$
