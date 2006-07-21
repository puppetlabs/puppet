module Puppet
    Puppet.type(:package).newpkgtype(:yum, :rpm) do
        include Puppet::Util
        # Install a package using 'yum'.
        def install
            cmd = "yum -y install %s" % self[:name]

            begin
                output = execute(cmd)
            rescue Puppet::ExecutionFailure => detail
                raise Puppet::PackageError.new(detail)
            end

            @states[:ensure].retrieve
            if @states[:ensure].is == :absent
                raise Puppet::PackageError.new(
                    "Could not find package %s" % self.name
                )
            end
        end

        # What's the latest package version available?
        def latest
            cmd = "yum list available %s" % self[:name] 

            begin
                output = execute(cmd)
            rescue Puppet::ExecutionFailure => detail
                raise Puppet::PackageError.new(detail)
            end

            if output =~ /#{self[:name]}\S+\s+(\S+)\s/
                return $1
            else
                # Yum didn't find updates, pretend the current
                # version is the latest
                return self[:version]
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
end

# $Id$
