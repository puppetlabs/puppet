# RPM packaging.  Should work anywhere that has rpm installed.
Puppet::Type.type(:package).provide :rpm do
    desc "RPM packaging support; should work anywhere with a working ``rpm``
        binary."

    VERSIONSTRING = "%{VERSION}-%{RELEASE}"

    commands :rpm => "rpm"

    def self.list
        packages = []

        # list out all of the packages
        begin
            execpipe("#{command(:rpm)} -q -a --qf '%{NAME} #{VERSIONSTRING}\n'") { |process|
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
                        hash[:provider] = self.name
                        packages.push Puppet.type(:package).installedpkg(hash)
                    else
                        raise "failed to match rpm line %s" % line
                    end
                }
            }
        rescue Puppet::ExecutionFailure
            raise Puppet::Error, "Failed to list packages"
        end

        return packages
    end

    def query
        fields = {
            :name => "NAME",
            :version => "VERSION",
            :description => "DESCRIPTION"
        }

        cmd = "#{command(:rpm)} -q #{@model[:name]} --qf '%s\n'" %
            "%{NAME} #{VERSIONSTRING}"

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
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
        unless source = @model[:source]
            @model.fail "RPMs must specify a package source"
        end
        
        cmd = "#{command(:rpm)} -q --qf '#{VERSIONSTRING}' -p #{@model[:source]}"
        version = execfail(cmd, Puppet::Error)

        return version
    end

    def install
        source = nil
        unless source = @model[:source]
            @model.fail "RPMs must specify a package source"
        end

        flag = "-i"
        if @model.is(:ensure) != :absent
            flag = "-U"
        end
        output = %x{#{command(:rpm)} #{flag} #{source} 2>&1}

        unless $? == 0
            raise Puppet::PackageError.new(output)
        end
    end

    def uninstall
        cmd = "#{command(:rpm)} -e %s" % @model[:name]
        output = %x{#{cmd}}
        if $? != 0
            raise output
        end
    end

    def update
        self.install
    end
end

# $Id$
