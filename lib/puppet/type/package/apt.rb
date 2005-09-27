module Puppet
    module PackagingType
        # A derivative of DPKG; this is how most people actually manage
        # Debian boxes, and the only thing that differs is that it can
        # install packages from remote sites.
        module APT
            include DPKG

            # Install a package using 'apt-get'.
            def install
                cmd = "apt-get install %s" % self.name

                Puppet.info "Executing %s" % cmd.inspect
                output = %x{#{cmd} 2>&1}

                unless $? == 0
                    raise Puppet::PackageError.new(output)
                end
            end
        end
    end
end
