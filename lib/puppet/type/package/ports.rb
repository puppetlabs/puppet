module Puppet
    Puppet.type(:package).newpkgtype(:ports, :openbsd) do
        # I hate ports
        %w{INTERACTIVE UNAME}.each do |var|
            if ENV.include?(var)
                ENV.delete(var)
            end
        end
        def install
            # -p: create a package
            # -N: install if the package is missing, otherwise upgrade
            # -P: prefer binary packages
            cmd = "/usr/local/sbin/portupgrade -p -N -P #{self[:name]}"

            self.debug "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        # If there are multiple packages, we only use the last one
        def latest
            cmd = "/usr/local/sbin/portversion -v #{self[:name]}"

            self.debug "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>/dev/null}.chomp
            line = output.split("\n").pop

            unless line =~ /^(\S+)\s+(\S)\s+(.+)$/
                # There's no "latest" version, so just return a placeholder
                return :latest
            end

            pkgstuff = $1
            match = $2
            info = $3

            unless pkgstuff =~ /^(\w+)-([0-9].+)$/
                raise Puppet::PackageError,
                    "Could not match package info '%s'" % pkgstuff
            end

            name, version = $1, $2

            if match == "=" or match == ">" 
                # we're up to date or more recent
                return version
            end

            # Else, we need to be updated; we need to pull out the new version

            unless info =~ /\((\w+) has (.+)\)/
                raise Puppet::PackageError,
                    "Could not match version info '%s'" % info
            end

            source, newversion = $1, $2

            debug "Newer version in %s" % source
            return newversion
        end

        def listcmd
            "pkg_info"
        end

        def query
            list

            if self[:version] and @states[:ensure].is != :absent
                return :listed
            else
                return nil
            end
        end

        def uninstall
            cmd = "/usr/local/sbin/pkg_deinstall #{self[:name]}"
            self.debug "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
            
        end

        def update
            install()
        end
    end
end

# $Id$
