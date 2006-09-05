Puppet::Type.type(:package).provide :dpkg do
    desc "Package management via ``dpkg``.  Because this only uses ``dpkg``
        and not ``apt``, you must specify the source of any packages you want
        to manage."

    commands :dpkg => "/usr/bin/dpkg"

    def self.list
        packages = []

        # dpkg only prints as many columns as you have available
        # which means we don't get all of the info
        # stupid stupid
        oldcol = ENV["COLUMNS"]
        ENV["COLUMNS"] = "500"

        # list out all of the packages
        open("| #{command(:dpkg)} -l") { |process|
            # our regex for matching dpkg output
            regex = %r{^(\S+)\s+(\S+)\s+(\S+)\s+(.+)$}
            fields = [:status, :name, :ensure, :description]
            hash = {}

            5.times { process.gets } # throw away the header

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
                        "Failed to match dpkg line %s" % line
                end
            }
        }
        ENV["COLUMNS"] = oldcol

        return packages
    end

    def query
        packages = []

        # dpkg only prints as many columns as you have available
        # which means we don't get all of the info
        # stupid stupid
        oldcol = ENV["COLUMNS"]
        ENV["COLUMNS"] = "500"
        fields = [:desired, :status, :error, :name, :ensure, :description]

        hash = {}
        # list out our specific package
        open("| #{command(:dpkg)} -l %s 2>/dev/null" % @model[:name]) { |process|
            # our regex for matching dpkg output
            regex = %r{^(.)(.)(.)\s(\S+)\s+(\S+)\s+(.+)$}

            # we only want the last line
            lines = process.readlines
            # we've got four header lines, so we should expect all of those
            # plus our output
            if lines.length < 5
                return nil
            end

            line = lines[-1]

            if match = regex.match(line)
                fields.zip(match.captures) { |field,value|
                    hash[field] = value
                }
                #packages.push Puppet.type(:package).installedpkg(hash)
            else
                raise Puppet::DevError,
                    "failed to match dpkg line %s" % line
            end
        }
        ENV["COLUMNS"] = oldcol

        if hash[:error] != " "
            raise Puppet::PackageError.new(
                "Package %s, version %s is in error state: %s" %
            [hash[:name], hash[:ensure], hash[:error]]
            )
        end

        # DPKG can discuss packages that are no longer installed, so allow that.
        if hash[:status] != "i"
            hash[:ensure] = :absent
        end

        return hash
    end

    def uninstall
        cmd = "#{command(:dpkg)} -r %s" % @model[:name]
        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
    end
end

# $Id$
