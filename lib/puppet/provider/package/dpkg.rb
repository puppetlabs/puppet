require 'puppet/provider/package'

Puppet::Type.type(:package).provide :dpkg, :parent => Puppet::Provider::Package do
    desc "Package management via ``dpkg``.  Because this only uses ``dpkg``
        and not ``apt``, you must specify the source of any packages you want
        to manage."

    commands :dpkg => "/usr/bin/dpkg"
    commands :dpkg_deb => "/usr/bin/dpkg-deb"
    commands :dpkgquery => "/usr/bin/dpkg-query"

    def self.instances
        packages = []

        # list out all of the packages
        cmd = "#{command(:dpkgquery)} -W --showformat '${Status} ${Package} ${Version}\\n'"
        Puppet.debug "Executing '%s'" % cmd
        execpipe(cmd) do |process|
            # our regex for matching dpkg output
            regex = %r{^(\S+) +(\S+) +(\S+) (\S+) (\S*)$}
            fields = [:desired, :error, :status, :name, :ensure]
            hash = {}

            # now turn each returned line into a package object
            process.each { |line|
                if hash = parse_line(line)
                    packages << new(hash)
                end
            }
        end

        return packages
    end

    REGEX = %r{^(\S+) +(\S+) +(\S+) (\S+) (\S*)$}
    FIELDS = [:desired, :error, :status, :name, :ensure]

    def self.parse_line(line)
        if match = REGEX.match(line)
            hash = {}

            FIELDS.zip(match.captures) { |field,value|
                hash[field] = value
            }

            hash[:provider] = self.name

            if hash[:status] == 'not-installed'
                hash[:ensure] = :purged
            elsif hash[:status] != "installed"
                hash[:ensure] = :absent
            end
        else
            Puppet.warning "Failed to match dpkg-query line %s" % line.inspect
            return nil
        end

        return hash
    end

    def install
        unless file = @resource[:source]
            raise ArgumentError, "You cannot install dpkg packages without a source"
        end

        args = []

        if @resource[:configfiles] == :keep
            args << '--force-confold'
        else
            args << '--force-confnew'
        end
        args << '-i' << file

        dpkg(*args)
    end

    def update
        self.install
    end

    # Return the version from the package.
    def latest
        output = dpkg_deb "--show", @resource[:source]
        matches = /^(\S+)\t(\S+)$/.match(output).captures
        unless matches[0].match( Regexp.escape(@resource[:name]) )
            warning "source doesn't contain named package, but %s" % matches[0]
        end
        matches[1]
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

        hash = self.class.parse_line(output) || {:ensure => :absent, :status => 'missing', :name => @resource[:name], :error => 'ok'}

        if hash[:error] != "ok"
            raise Puppet::Error.new(
                "Package %s, version %s is in error state: %s" %
                    [hash[:name], hash[:ensure], hash[:error]]
            )
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
