require 'puppet/provider/package'

# Packaging on OpenBSD.  Doesn't work anywhere else that I know of.
Puppet::Type.type(:package).provide :openbsd, :parent => Puppet::Provider::Package do
    include Puppet::Util::Execution
    desc "OpenBSD's form of ``pkg_add`` support."

    commands :pkginfo => "pkg_info", :pkgadd => "pkg_add", :pkgdelete => "pkg_delete"

    defaultfor :operatingsystem => :openbsd
    confine :operatingsystem => :openbsd

    def self.instances
        packages = []

        begin
            execpipe(listcmd()) do |process|
                # our regex for matching pkg_info output
                regex = %r{^(\S+)-([^-\s]+)\s+(.+)}
                fields = [:name, :ensure, :description]
                hash = {}

                # now turn each returned line into a package object
                process.each { |line|
                    if match = regex.match(line)
                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }
                        yup = nil
                        name = hash[:name]

                        hash[:provider] = self.name

                        packages << new(hash)
                        hash = {}
                    else
                        # Print a warning on lines we can't match, but move
                        # on, since it should be non-fatal
                        warning("Failed to match line %s" % line)
                    end
                }
            end

            return packages
        rescue Puppet::ExecutionFailure
            return nil
        end
    end

    def self.listcmd
        [command(:pkginfo), " -a"]
    end

    def install
        should = @resource.should(:ensure)

        unless @resource[:source]
            raise Puppet::Error,
                "You must specify a package source for BSD packages"
        end

        if @resource[:source] =~ /\/$/
            withenv :PKG_PATH => @resource[:source] do
                pkgadd @resource[:name]
            end
        else
            pkgadd @resource[:source]
        end

    end

    def query
        hash = {}
        info = pkginfo @resource[:name]

        # Search for the version info
        if info =~ /Information for (inst:)?#{@resource[:name]}-(\S+)/
            hash[:ensure] = $2
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
        pkgdelete @resource[:name]
    end
end

