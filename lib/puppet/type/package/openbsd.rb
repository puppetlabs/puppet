module Puppet
    Puppet.type(:package).newpkgtype(:openbsd) do
        def listcmd
            "pkg_info -a"
        end

        module_function :listcmd

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

            if self.is_a? Puppet::Type
                debug "Executing %s" % listcmd().inspect
            else
                Puppet.debug "Executing %s" % listcmd().inspect
            end
            # list out all of the packages
            open("| #{listcmd()}") { |process|
                # our regex for matching pkg_info output
                regex = %r{^(\S+)-([^-\s]+)\s+(.+)}
                fields = [:name, :version, :description]
                hash = {}

                # now turn each returned line into a package object
                process.each { |line|
                    hash.clear
                    if match = regex.match(line)
                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }
                        yup = nil
                        name = hash[:name]
                        hash[:ensure] = :present

                        if self.is_a? Puppet::Type and type = self[:type]
                            hash[:type] = type
                        elsif self.is_a? Module and self.respond_to? :name
                            hash[:type] = self.name
                        else
                            raise Puppet::DevError, "Cannot determine package type"
                        end

                        pkg = Puppet.type(:package).installedpkg(hash)
                        packages << pkg
                    else
                        # Print a warning on lines we can't match, but move
                        # on, since it should be non-fatal
                        warning("Failed to match line %s" % line)
                    end
                }
            }

            # Mark as absent any packages we didn't find
            Puppet.type(:package).each do |pkg|
                unless packages.include? pkg
                    pkg.is = [:ensure, :absent] 
                end
            end

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
