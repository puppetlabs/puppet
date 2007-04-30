Puppet.type(:package).provide :rug, :parent => :rpm do
    desc "Support for suse ``rug`` package manager."

    commands :rug => "/usr/bin/rug"
    defaultfor :operatingsystem => :suse 
    confine    :operatingsystem => :suse

    # Install a package using 'rug'.
    def install
        should = @model.should(:ensure)
        self.debug "Ensuring => #{should}"
        wanted = @model[:name]

        # XXX: We don't actually deal with epochs here.
        case should
        when true, false, Symbol
            # pass
        else
            # Add the package version
            wanted += "-%s" % should
        end
        output = rug "--quiet", :install, "-y", wanted

        unless self.query
            raise Puppet::ExecutionFailure.new(
                "Could not find package %s" % self.name
            )
        end
    end

    # What's the latest package version available?
    def latest
        #rug can only get a list of *all* available packages?
        output = rug "list-updates"

        if output =~ /#{@model[:name]}\s*\|\s*([0-9\.\-]+)/
            return $1
        else
            # rug didn't find updates, pretend the current
            # version is the latest
            return @model.is(:ensure)
        end
    end

    def update
        # rug install can be used for update, too
        self.install
    end

    def versionable?
        true
    end
end
