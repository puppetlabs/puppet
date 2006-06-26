module Puppet
    Puppet.type(:package).newpkgtype(:rpm) do
        VERSIONSTRING = "%{VERSION}-%{RELEASE}"
        def query
            fields = {
                :name => "NAME",
                :version => "VERSION",
                :description => "DESCRIPTION"
            }

            cmd = "rpm -q #{self[:name]} --qf '%s\n'" %
                "%{NAME} #{VERSIONSTRING}"

            self.debug "Executing %s" % cmd.inspect
            # list out all of the packages
            output = %x{#{cmd} 2>/dev/null}.chomp

            if $? != 0
                #if Puppet[:debug]
                #    puts output
                #end
                return nil
            end

            regex = %r{^(\S+)\s+(\S+)}
            #fields = [:name, :ensure, :description]
            fields = [:name, :version]
            hash = {}
            if match = regex.match(output)
                fields.zip(match.captures) { |field,value|
                    hash[field] = value
                }
            else
                raise Puppet::DevError,
                    "Failed to match rpm output '%s'" %
                    output
            end

            hash[:ensure] = :present

            return hash
        end

        # Here we just retrieve the version from the file specified in the source.
        def latest
            unless source = self[:source]
                self.fail "RPMs must specify a package source"
            end
            
            cmd = "rpm -q --qf '#{VERSIONSTRING}' -p #{self[:source]}"
            self.debug "Executing %s" % cmd.inspect
            version = %x{#{cmd}}

            return version
        end

        def list
            packages = []

            # list out all of the packages
            open("| rpm -q -a --qf '%{NAME} #{VERSIONSTRING}\n'") { |process|
                # our regex for matching dpkg output
                regex = %r{^(\S+)\s+(\S+)}
                fields = [:name, :ensure]
                hash = {}

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
                        raise "failed to match rpm line %s" % line
                    end
                }
            }

            return packages
        end

        def install
            source = nil
            unless source = self[:source]
                self.fail "RPMs must specify a package source"
            end

            flag = "-i"
            if @states[:ensure].is != :absent
                flag = "-U"
            end
            output = %x{rpm #{flag} #{source} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        def uninstall
            cmd = "rpm -e %s" % self[:name]
            output = %x{#{cmd}}
            if $? != 0
                raise output
            end
        end

        def update
            self.install
        end
    end
end
