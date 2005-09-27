module Puppet
    module PackagingType
        module RPM
            def query
                fields = {
                    :name => "NAME",
                    :install => "VERSION",
                    :description => "DESCRIPTION"
                }

                cmd = "rpm -q --qf '%s\n'" %
                    %w{NAME VERSION DESCRIPTION}.collect { |str|
                        "%{#{str}}"
                    }.join(" ")

                # list out all of the packages
                str = %x{#{cmd} 2>/dev/null}.chomp

                if $? != 0
                    return nil
                end

                regex = %r{^(\S+)\s+(\S+)\s+(.+)}
                fields = [:name, :install, :description]
                hash = {}
                if match = regex.match(str)
                    fields.zip(match.captures) { |field,value|
                        hash[field] = value
                    }
                else
                    raise Puppet::DevError,
                        "Failed to match rpm output '%s'" %
                        str
                end

                return hash
            end

            def list
                packages = []

                # list out all of the packages
                open("| rpm -q -a --qf '%{NAME} %{VERSION}\n'") { |process|
                    # our regex for matching dpkg output
                    regex = %r{^(\S+)\s+(\S+)}
                    fields = [:name, :install]
                    hash = {}

                    # now turn each returned line into a package object
                    process.each { |line|
                        if match = regex.match(line)
                            hash.clear

                            fields.zip(match.captures) { |field,value|
                                hash[field] = value
                            }
                            packages.push Puppet::Type::Package.installedpkg(hash)
                        else
                            raise "failed to match rpm line %s" % line
                        end
                    }
                }

                return packages
            end

            # we need package retrieval mechanisms before we can have package
            # installation mechanisms...
            #type.install = proc { |pkg|
            #    raise "installation not implemented yet"
            #}

            def remove
                cmd = "rpm -e %s" % self.name
                output = %x{#{cmd}}
                if $? != 0
                    raise output
                end
            end
        end
    end
end
