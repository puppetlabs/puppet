module Puppet
    Puppet.type(:package).newpkgtype(:yum, :rpm) do

        # Install a package using 'yum'.
        def install
            cmd = "yum -y install %s" % self[:name]

            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        # What's the latest package version available?
        def latest
            cmd = "yum list available %s" % self[:name] 
            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
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
