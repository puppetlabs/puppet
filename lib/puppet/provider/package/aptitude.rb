Puppet::Type.type(:package).provide :aptitude, :parent => :apt do
    desc "Package management via ``aptitude``."

    commands :aptitude => "/usr/bin/aptitude"
    commands :aptcache => "/usr/bin/apt-cache"

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    def aptcmd(arg)
        # Apparently aptitude hasn't always supported a -q flag.
        aptitude(arg.gsub(/-q/,""))
    end
end

# $Id$
