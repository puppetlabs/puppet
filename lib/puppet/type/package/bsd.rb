module Puppet
    Puppet.type(:package).newpkgtype(:bsd) do
        def install
            should = self.should(:ensure)

            unless self[:source]
                raise Puppet::Error,
                    "You must specify a package source for BSD packages"
            end

            cmd = "pkg_add #{self[:source]}"

            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        def query
            hash = {}
            # list out our specific package
            info = %x{pkg_info #{self[:name]} 2>/dev/null}

            # Search for the version info
            if info =~ /Information for #{self[:name]}-(\S+)/
                hash[:version] = $1
                hash[:ensure] = :present
            else
                return nil
            end

            # And the description
            if info =~ /Comment:\s*\n(.+)/
                hash[:description] = $1
            end

            return hash
        end

        def list
            packages = []

            # list out all of the packages
            open("| pkg_info -a") { |process|
                # our regex for matching dpkg output
                regex = %r{^(\S+)-(\d\S+)\s+(.+)}
                fields = [:name, :version, :description]
                hash = {}

                # now turn each returned line into a package object
                process.each { |line|
                    if match = regex.match(line)
                        hash.clear

                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }
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
            cmd = "pkg_delete %s" % self[:name]
            output = %x{#{cmd} 2>&1}
            if $? != 0
                raise Puppet::PackageError.new(output)
            end
        end
    end
end

# $Id$
