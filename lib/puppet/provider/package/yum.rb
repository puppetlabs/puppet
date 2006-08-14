Puppet::Type.type(:package).provide :yum, :parent => :rpm do
    desc "Support via ``yum``."
    commands :yum => "yum", :rpm => "rpm"

    defaultfor :operatingsystem => :fedora

    # Install a package using 'yum'.
    def install
        cmd = "#{command(:yum)} -y install %s" % @model[:name]

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end

        unless self.query
            raise Puppet::PackageError.new(
                "Could not find package %s" % self.name
            )
        end
    end

    # What's the latest package version available?
    def latest
        cmd = "#{command(:yum)} list available %s" % @model[:name] 

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end

        if output =~ /#{@model[:name]}\S+\s+(\S+)\s/
            return $1
        else
            # Yum didn't find updates, pretend the current
            # version is the latest
            return @model[:version]
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
