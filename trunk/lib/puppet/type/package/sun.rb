module Puppet
    Puppet.type(:package).newpkgtype(:sun) do
        # Get info on a package, optionally specifying a device.
        def info2hash(device = nil)
            names = {
                "PKGINST" => :name,
                "NAME" => nil,
                "CATEGORY" => :category,
                "ARCH" => :platform,
                "VERSION" => :version,
                "BASEDIR" => :root,
                "HOTLINE" => nil,
                "EMAIL" => nil,
                "VSTOCK" => nil,
                "VENDOR" => :vendor,
                "DESC" => :description,
                "PSTAMP" => nil,
                "INSTDATE" => nil,
                "STATUS" => nil,
                "FILES" => nil
            }

            hash = {}
            cmd = "pkginfo -l"
            if device
                cmd += " -d #{device}"
            end
            cmd += " #{self[:name]} 2>/dev/null"

            # list out all of the packages
            open("| #{cmd}") { |process|
                # we're using the long listing, so each line is a separate
                # piece of information
                process.each { |line|
                    case line
                    when /^$/:  # ignore
                    when /\s*([A-Z]+):\s+(.+)/:
                        name = $1
                        value = $2
                        if names.include?(name)
                            unless names[name].nil?
                                hash[names[name]] = value
                            end
                        else
                            self.notice "Ignoring unknown name %s" % name
                        end
                    when /\s+\d+.+/:
                        # nothing; we're ignoring the FILES info
                    end
                }
            }

            if hash.empty?
                return nil
            else
                return hash
            end
        end

        def install
            unless self[:source]
                raise Puppet::Error, "Sun packages must specify a package source"
            end
            cmd = ["pkgadd"]

            if self[:adminfile]
                cmd += ["-a", self[:adminfile]]
            end

            if self[:responsefile]
                cmd += ["-r", self[:responsefile]]
            end

            cmd += ["-d", self[:source]]
            cmd += ["-n", self[:name]]
            cmd << "2>&1"
            cmd = cmd.join(" ")

            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        # Retrieve the version from the current package file.
        def latest
            hash = info2hash(self[:source])
            hash[:ensure]
        end

        def list
            packages = []
            hash = {}
            names = {
                "PKGINST" => :name,
                "NAME" => nil,
                "CATEGORY" => :category,
                "ARCH" => :platform,
                "VERSION" => :version,
                "BASEDIR" => :root,
                "HOTLINE" => nil,
                "EMAIL" => nil,
                "VENDOR" => :vendor,
                "DESC" => :description,
                "PSTAMP" => nil,
                "INSTDATE" => nil,
                "STATUS" => nil,
                "FILES" => nil
            }

            # list out all of the packages
            open("| pkginfo -l 2>&1") { |process|
                # we're using the long listing, so each line is a separate
                # piece of information
                process.each { |line|
                    case line
                    when /^$/:
                        if self.is_a? Puppet::Type and type = self[:type]
                            hash[:type] = type
                        elsif self.is_a? Module and self.respond_to? :name
                            hash[:type] = self.name
                        else
                            raise Puppet::DevError, "Cannot determine package type"
                        end

                        hash[:ensure] = :present

                        packages.push Puppet.type(:package).installedpkg(hash)
                        hash.clear
                    when /\s*(\w+):\s+(.+)/:
                        name = $1
                        value = $2
                        if names.include?(name)
                            unless names[name].nil?
                                hash[names[name]] = value
                            end
                        else
                            raise "Could not find %s" % name
                        end
                    when /\s+\d+.+/:
                        # nothing; we're ignoring the FILES info
                    end
                }
            }
            return packages
        end

        def query
            info2hash()
        end

        def uninstall
            cmd = "pkgrm -n %s 2>&1" % self[:name]
            output = %x{#{cmd}}
            if $? != 0
                raise Puppet::Error, "Removal of %s failed: %s" % [self.name, output]
            end
        end

        # Remove the old package, and install the new one
        def update
            if @states[:ensure].is != :absent
                self.uninstall
            end
            self.install
        end
    end
end
