# Packaging on OpenBSD.  Doesn't work anywhere else that I know of.
Puppet::Type.type(:package).provide :openbsd do
    desc "OpenBSD's form of ``pkg_add`` support."

    commands :info => "pkg_info", :add => "pkg_add", :delete => "pkg_delete"

    defaultfor :operatingsystem => :openbsd

    def self.list
        packages = []

        begin
            execpipe(listcmd()) do |process|
                # our regex for matching pkg_info output
                regex = %r{^(\S+)-([^-\s]+)\s+(.+)}
                fields = [:name, :ensure, :description]
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

                        hash[:provider] = self.name

                        pkg = Puppet.type(:package).installedpkg(hash)
                        packages << pkg
                    else
                        # Print a warning on lines we can't match, but move
                        # on, since it should be non-fatal
                        warning("Failed to match line %s" % line)
                    end
                }
            end
            # Mark as absent any packages we didn't find
            Puppet.type(:package).each do |pkg|
                unless packages.include? pkg
                    pkg.is = [:ensure, :absent] 
                end
            end

            return packages
        rescue Puppet::ExecutionFailure
            return nil
        end
    end

    def self.listcmd
        "#{command(:info)} -a"
    end

    def install
        should = @model[:ensure]

        unless @model[:source]
            raise Puppet::Error,
                "You must specify a package source for BSD packages"
        end

        cmd = command(:add) + " " + @model[:source]

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
    end

    def query
        hash = {}
        begin
            # list out our specific package
            info = execute("#{command(:info)} #{@model[:name]}")
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(info)
        end

        # Search for the version info
        if info =~ /Information for #{@model[:name]}-(\S+)/
            hash[:ensure] = $1
        else
            return nil
        end

        # And the description
        if info =~ /Comment:\s*\n(.+)/
            hash[:description] = $1
        end

        return hash
    end

    def uninstall
        cmd = "#{command(:delete)} %s" % @model[:name]
        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
    end
end

# $Id$
