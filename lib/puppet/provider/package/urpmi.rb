Puppet::Type.type(:package).provide :urpmi, :parent => :rpm, :source => :rpm do
    desc "Support via ``urpmi``."
    commands :urpmi => "urpmi", :urpmq => "urpmq", :rpm => "rpm"

    if command('rpm')
        confine :true => begin
                rpm('-ql', 'rpm')
           rescue Puppet::ExecutionFailure
               false
           else
               true
           end
    end

    defaultfor :operatingsystem => [:mandriva, :mandrake]

    has_feature :versionable

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
        output = urpmq "-S", @resource[:name]

        if output =~ /^#{Regexp.escape @resource[:name]}\s+:\s+.*\(\s+(\S+)\s+\)/
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

