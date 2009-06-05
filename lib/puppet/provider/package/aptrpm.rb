Puppet::Type.type(:package).provide :aptrpm, :parent => :rpm, :source => :rpm do
    # Provide sorting functionality
    include Puppet::Util::Package

    desc "Package management via ``apt-get`` ported to ``rpm``."

    has_feature :versionable

    commands :aptget => "apt-get"
    commands :aptcache => "apt-cache"
    commands :rpm => "rpm"

    if command('rpm')
        confine :true => begin
                rpm('-ql', 'rpm')
           rescue Puppet::ExecutionFailure
               false
           else
               true
           end
    end

    # Install a package using 'apt-get'.  This function needs to support
    # installing a specific version.
    def install
        should = @resource.should(:ensure)

        str = @resource[:name]
        case should
        when true, false, Symbol
            # pass
        else
            # Add the package version
            str += "=%s" % should
        end
        cmd = %w{-q -y}

        cmd << 'install' << str

        aptget(*cmd)
    end

    # What's the latest package version available?
    def latest
        output = aptcache :showpkg,  @resource[:name]

        if output =~ /Versions:\s*\n((\n|.)+)^$/
            versions = $1
            available_versions = versions.split(/\n/).collect { |version|
                if version =~ /^([^\(]+)\(/
                    $1
                else
                    self.warning "Could not match version '%s'" % version
                    nil
                end
            }.reject { |vers| vers.nil? }.sort { |a,b|
                versioncmp(a,b)
            }

            if available_versions.length == 0
                self.debug "No latest version"
                if Puppet[:debug]
                    print output
                end
            end

            # Get the latest and greatest version number
            return available_versions.pop
        else
            self.err "Could not match string"
        end
    end

    def update
        self.install
    end

    def uninstall
        aptget "-y", "-q", 'remove', @resource[:name]
    end

    def purge
        aptget '-y', '-q', 'remove', '--purge', @resource[:name]
    end
end

