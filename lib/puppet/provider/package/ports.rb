Puppet::Type.type(:package).provide :ports, :parent => :freebsd, :source => :freebsd do
    desc "Support for FreeBSD's ports.  Again, this still mixes packages and ports."

    commands :portupgrade => "/usr/local/sbin/portupgrade",
             :portversion => "/usr/local/sbin/portversion",
             :portuninstall => "/usr/local/sbin/pkg_deinstall",
             :portinfo => "/usr/sbin/pkg_info"

    defaultfor :operatingsystem => :freebsd

    # I hate ports
    %w{INTERACTIVE UNAME}.each do |var|
        if ENV.include?(var)
            ENV.delete(var)
        end
    end

    def install
        # -N: install if the package is missing, otherwise upgrade
        # -M: yes, we're a batch, so don't ask any questions
        cmd = %w{-N -M BATCH=yes} << @resource[:name]

        output = portupgrade(*cmd)
        if output =~ /\*\* No such /
            raise Puppet::ExecutionFailure, "Could not find package %s" % @resource[:name]
        end
    end

    # If there are multiple packages, we only use the last one
    def latest
        cmd = ["-v", @resource[:name]]

        begin
            output = portversion(*cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
        line = output.split("\n").pop

        unless line =~ /^(\S+)\s+(\S)\s+(.+)$/
            # There's no "latest" version, so just return a placeholder
            return :latest
        end

        pkgstuff = $1
        match = $2
        info = $3

        unless pkgstuff =~ /^(\S+)-([^-\s]+)$/
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

    def query
        self.class.instances.each do |instance|
            if instance.name == self.name
                return instance.properties
            end
        end

        return nil
    end

    def uninstall
        portuninstall @resource[:name]
    end

    def update
        install()
    end
end

