module Puppet
    module PackagingType
        # A derivative of DPKG; this is how most people actually manage
        # Debian boxes, and the only thing that differs is that it can
        # install packages from remote sites.
        module Yum
            include RPM

            # Install a package using 'apt-get'.
            def install
                cmd = "yum -y install %s" % self.name

                self.info "Executing %s" % cmd.inspect
                output = %x{#{cmd} 2>&1}

                unless $? == 0
                    raise Puppet::PackageError.new(output)
                end
            end

            # What's the latest package version available?
            def latest
                cmd = "yum list %s" % self.name 
                output = %x{#{cmd} 2>&1}

                unless $? == 0
                    raise Puppet::PackageError.new(output)
                end

                if output =~ /#{self.name}\S+\s+(\S+)\s/
                    return $1
                else
                    self.debug "No version"
                    if Puppet[:debug]
                        print output
                    end

                    return nil
                end
            end

            def update
                cmd = "yum -y update %s" % self.name

                self.info "Executing %s" % cmd.inspect
                output = %x{#{cmd} 2>&1}

                unless $? == 0
                    raise Puppet::PackageError.new(output)
                end
            end

            def versionable?
                false
            end
        end
    end
end
