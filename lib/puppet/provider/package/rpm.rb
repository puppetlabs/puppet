# RPM packaging.  Should work anywhere that has rpm installed.
Puppet::Type.type(:package).provide :rpm do
    desc "RPM packaging support; should work anywhere with a working ``rpm``
        binary."

    # The query format by which we identify installed packages
    NVRFORMAT = "%{NAME}-%{VERSION}-%{RELEASE}"

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

    # Find the fully versioned package name and the version alone. Returns
    # a hash with entries :instance => fully versioned package name, and 
    # :ensure => version-release
    def query
        cmd = ["-q", @model[:name], "--qf", "#{NVRFORMAT} #{VERSIONSTRING}\n"]

        begin
            output = rpm *cmd
        rescue Puppet::ExecutionFailure
            return nil
        end

        regex = %r{^(\S+)\s+(\S+)}
        fields = [:instance, :ensure]
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

        @nvr = hash[:instance]

        return hash
    end

    # Here we just retrieve the version from the file specified in the source.
    def latest
        unless source = @model[:source]
            @model.fail "RPMs must specify a package source"
        end
        
        cmd = [command(:rpm), "-q", "--qf", "#{VERSIONSTRING}", "-p", "#{@model[:source]}"]
        version = execfail(cmd, Puppet::Error)
        return version
    end

    def install
        source = nil
        unless source = @model[:source]
            @model.fail "RPMs must specify a package source"
        end
        if @model.should(:ensure) == @model.is(:ensure) ||
           @model.should(:ensure) == :latest && @model.is(:ensure) == latest
            # RPM gets pissy if you try to install an already 
            # installed package
            return
        end

        flag = "-i"
        if @model.is(:ensure) != :absent
            flag = "-U"
        end

        rpm flag, "--oldpackage", source
    end

    def uninstall
        rpm "-e", nvr
    end

    def update
        self.install
    end

    def versionable?
        true
    end

    def nvr
        query unless @nvr
        @nvr
    end
end

# $Id$
