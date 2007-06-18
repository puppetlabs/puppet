Puppet::Type.type(:package).provide :urpmi, :parent => :rpm, :source => :rpm do
    desc "Support via ``urpmi``."
    commands :urpmi => "urpmi", :rpm => "rpm"

    defaultfor :operatingsystem => [:mandriva, :mandrake]

    def install
        should = @resource.should(:ensure)
        self.debug "Ensuring => #{should}"
        wanted = @resource[:name]

        # XXX: We don't actually deal with epochs here.
        case should
        when true, false, Symbol
            # pass
        else
            # Add the package version
            wanted += "-%s" % should
        end

        output = urpmi "--auto", wanted

        unless self.query
            raise Puppet::Error.new(
                "Could not find package %s" % self.name
            )
        end
    end

    # What's the latest package version available?
    def latest
        output = urpmi "-S",  :available, @resource[:name]

        if output =~ /^#{@resource[:name]}\S+\s+(\S+)\s/
            return $1
        else
            # urpmi didn't find updates, pretend the current
            # version is the latest
            return @resource[:ensure]
        end
    end

    def update
        # Install in urpmi can be used for update, too
        self.install
    end
end

# $Id$
