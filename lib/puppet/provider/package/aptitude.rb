Puppet::Type.type(:package).provide :aptitude, :parent => :apt, :source => :dpkg do
    desc "Package management via ``aptitude``."

    has_feature :versionable

    commands :aptitude => "/usr/bin/aptitude"
    commands :aptcache => "/usr/bin/apt-cache"

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    def aptget(*args)
        args.flatten!
        # Apparently aptitude hasn't always supported a -q flag.
        if args.include?("-q")
            args.delete("-q")
        end
        output = aptitude(*args)

        # Yay, stupid aptitude doesn't throw an error when the package is missing.
        if args.include?(:install) and output =~ /Couldn't find any package/
            raise Puppet::Error.new(
                "Could not find package %s" % self.name
            )
        end
    end

    def purge
        aptitude '-y', 'purge', @resource[:name]
    end
end

