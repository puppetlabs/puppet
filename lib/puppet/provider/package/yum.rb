Puppet::Type.type(:package).provide :yum, :parent => :rpm do
    desc "Support via ``yum``."
    commands :yum => "yum", :rpm => "rpm"

    defaultfor :operatingsystem => :fedora

    # Install a package using 'yum'.
    def install
        output = yum "-y", :install, @model[:name]

        unless self.query
            raise Puppet::Error.new(
                "Could not find package %s" % self.name
            )
        end
    end

    # What's the latest package version available?
    def latest
        output = yum :list, :available, @model[:name]

        if output =~ /^#{@model[:name]}\S+\s+(\S+)\s/
            return $1
        else
            # Yum didn't find updates, pretend the current
            # version is the latest
            return @model[:ensure]
        end
    end

    def update
        # Install in yum can be used for update, too
        self.install
    end

    def versionable?
        false
    end
end

# $Id$
