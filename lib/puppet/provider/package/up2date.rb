Puppet.type(:package).provide :up2date, :parent => :rpm do
    desc "Support for Red Hat's proprietary ``up2date`` package update
        mechanism."

    commands :up2date => "/usr/sbin/up2date-nox"

    # Install a package using 'up2date'.
    def install
        up2date "-u %s" % @model[:name]

        #@states[:ensure].retrieve
        #if @states[:ensure].is == :absent
        unless self.query
            raise Puppet::ExecutionFailure.new(
                "Could not find package %s" % self.name
            )
        end
    end

    # What's the latest package version available?
    def latest
        #up2date can only get a list of *all* available packages?
        #cmd = "/usr/sbib/up2date-nox --show-available %s" % self[:name] 
        output = up2date "--show-available"

        if output =~ /#{@model[:name]}-(\d+.*)\.\w+/
            return $1
        else
            # up2date didn't find updates, pretend the current
            # version is the latest
            return @model.is(:ensure)
        end
    end

    def update
        # Install in up2date can be used for update, too
        self.install
    end

    def versionable?
        false
    end
end

# $Id$
