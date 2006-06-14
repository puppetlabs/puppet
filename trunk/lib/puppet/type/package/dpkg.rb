module Puppet
    Puppet.type(:package).newpkgtype(:dpkg) do
        def query
            packages = []

            # dpkg only prints as many columns as you have available
            # which means we don't get all of the info
            # stupid stupid
            oldcol = ENV["COLUMNS"]
            ENV["COLUMNS"] = "500"
            fields = [:desired, :status, :error, :name, :version, :description]

            hash = {}
            # list out our specific package
            open("| /usr/bin/dpkg -l %s 2>/dev/null" % self[:name]) { |process|
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
                        [hash[:name], hash[:version], hash[:error]]
                )
            end

            if hash[:status] == "i"
                hash[:ensure] = :present
            else
                hash[:ensure] = :absent
            end

            return hash
        end

        def list
            packages = []

            # dpkg only prints as many columns as you have available
            # which means we don't get all of the info
            # stupid stupid
            oldcol = ENV["COLUMNS"]
            ENV["COLUMNS"] = "500"

            # list out all of the packages
            open("| /usr/bin/dpkg -l") { |process|
                # our regex for matching dpkg output
                regex = %r{^(\S+)\s+(\S+)\s+(\S+)\s+(.+)$}
                fields = [:status, :name, :version, :description]
                hash = {}

                5.times { process.gets } # throw away the header

                # now turn each returned line into a package object
                process.each { |line|
                    if match = regex.match(line)
                        hash.clear

                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }

                        if self.is_a? Puppet::Type and type = self[:type]
                            hash[:type] = type
                        elsif self.is_a? Module and self.respond_to? :name
                            hash[:type] = self.name
                        else
                            raise Puppet::DevError, "Cannot determine package type"
                        end
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

        def uninstall
            cmd = "/usr/bin/dpkg -r %s" % self[:name]
            output = %x{#{cmd} 2>&1}
            if $? != 0
                raise Puppet::PackageError.new(output)
            end
        end
    end
end

# $Id$
