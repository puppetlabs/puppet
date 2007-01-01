Puppet::Type.type(:package).provide :aptitude, :parent => :apt do
    desc "Package management via ``aptitude``."

    commands :aptitude => "/usr/bin/aptitude"
    commands :aptcache => "/usr/bin/apt-cache"

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    def aptcmd(*args)
        args.flatten!
        # Apparently aptitude hasn't always supported a -q flag.
        if args.include?("-q")
            args.delete("-q")
        end
        output = aptitude(*args)

        # Yay, stupid aptitude doesn't throw an error when the package is missing.
        if args.include?(:install) and output =~ /0 newly installed/
            raise Puppet::Error.new(
                "Could not find package %s" % self.name
            )
        end
    end
end

# $Id$
