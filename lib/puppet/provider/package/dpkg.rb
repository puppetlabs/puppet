Puppet::Type.type(:package).provide :dpkg do
    desc "Package management via ``dpkg``.  Because this only uses ``dpkg``
        and not ``apt``, you must specify the source of any packages you want
        to manage."

    commands :dpkg => "/usr/bin/dpkg"
    commands :dpkgquery => "/usr/bin/dpkg-query"
    
    def self.list
        packages = []

        # list out all of the packages
        open("| #{command(:dpkgquery)} -W --showformat '${Status} ${Package} ${Version}\\n'") { |process|
            # our regex for matching dpkg output
            regex = %r{^(\S+ +\S+ +\S+) (\S+) (\S+)$}
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

                    packages.push Puppet.type(:package).installedpkg(hash)
                else
                    raise Puppet::DevError,
                        "Failed to match dpkg-query line %s" % line
                end
            }
        }

        return packages
    end

    def query
        packages = []

        fields = [:desired, :error, :status, :name, :ensure]

        hash = {}
        # list out our specific package
        open("| #{command(:dpkgquery)} -W --showformat '${Status} ${Package} ${Version}\\n' %s" % @model[:name]) { |process|
            # our regex for matching dpkg-query output
            regex = %r{^(\S+) (\S+) (\S+) (\S+) (\S+)$}

            lines = process.readlines.collect {|l| l.chomp }

            line = lines[0]
            
            if match = regex.match(line)
                fields.zip(match.captures) { |field,value|
                    hash[field] = value
                }
            else
                hash = {:ensure => :absent, :status => 'missing', :name => @model[:name], :error => 'ok'}
            end
        }

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
        dpkg "-r %s" % @model[:name]
    end
end

# $Id$
