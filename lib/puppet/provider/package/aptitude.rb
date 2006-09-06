Puppet::Type.type(:package).provide :aptitude, :parent => :apt do
    desc "Package management via ``aptitude``."

    commands :aptitude => "/usr/bin/aptitude"
    commands :aptcache => "/usr/bin/apt-cache"

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    def aptcmd(arg)
        aptitude(arg)
    end
end

# $Id$
