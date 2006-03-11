module Puppet
    Puppet.type(:package).newpkgtype(:rpm) do
        def query
            fields = {
                :name => "NAME",
                :version => "VERSION",
                :description => "DESCRIPTION"
            }

            cmd = "rpm -q #{self[:name]} --qf '%s\n'" %
                "%{NAME} %{VERSION}-%{RELEASE}"

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

        def list
            packages = []

            # list out all of the packages
            open("| rpm -q -a --qf '%{NAME} %{VERSION}\n'") { |process|
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

            output = %x{rpm -i #{source} 2>&1}

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
    end
end
