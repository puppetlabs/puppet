Puppet.type(:package).provide :up2date, :parent => :rpm do
    desc "Support for Red Hat's proprietary ``up2date`` package update
        mechanism."

    commands :up2date => "/usr/sbin/up2date-nox"

    # Install a package using 'up2date'.
    def install
        cmd = "#{command(:up2date)} -u %s" % @model[:name]

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end

        #@states[:ensure].retrieve
        #if @states[:ensure].is == :absent
        unless self.query
            raise Puppet::PackageError.new(
                "Could not find package %s" % self.name
            )
        end
    end

    # What's the latest package version available?
    def latest
        #up2date can only get a list of *all* available packages?
        #cmd = "/usr/sbib/up2date-nox --show-available %s" % self[:name] 
        cmd = "#{command(:up2date)} --show-available"
        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end

        if output =~ /#{@model[:name]}-(\d+.*)\.\w+/
            return $1
        else
            # up2date didn't find updates, pretend the current
            # version is the latest
            return @model[:version]
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
