module Puppet
    Puppet.type(:package).newpkgtype(:darwinport) do
        def port
            "/opt/local/bin/port"
        end

        def eachpkgashash
            # list out all of the packages
            open("| #{port} list installed") { |process|
                regex = %r{(\S+)\s+@(\S+)\s+(\S+)}
                fields = [:name, :version, :location]
                hash = {}

                # now turn each returned line into a package object
                process.each { |line|
                    hash.clear

                    if match = regex.match(line)
                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }

                        hash.delete :location
                        hash[:ensure] = hash[:version]
                        yield hash.dup
                    else
                        raise Puppet::DevError,
                            "Failed to match dpkg line %s" % line
                    end
                }
            }
        end

        def install
            should = self.should(:ensure)

            # Seems like you can always say 'upgrade'
            cmd = "#{port()} upgrade #{self[:name]}"

            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        def list
            packages = []

            eachpkgashash do |hash|
                pkg = Puppet.type(:package).installedpkg(hash)
                packages << pkg
            end

            return packages
        end

        def query
            version = nil
            eachpkgashash do |hash|
                if hash[:name] == self[:name]
                    return hash
                end
            end

            return nil
        end

        def latest
            info = %x{#{port()} search '^#{self[:name]}$' 2>/dev/null}

            if $? != 0 or info =~ /^Error/
                return nil
            end

            ary = info.split(/\s+/)
            version = ary[2].sub(/^@/, '')

            return version
        end

        def uninstall
            cmd = "#{port()} uninstall #{self[:name]}"
            output = %x{#{cmd} 2>&1}
            if $? != 0
                raise Puppet::PackageError.new(output)
            end
        end

        def update
            return install()
        end
    end
end

# $Id$
