module Puppet
    Puppet.type(:package).newpkgtype(:sunpkg) do
        def install
            unless self[:source]
                raise Puppet::Error, "Sun packages must specify a package source"
            end
            cmd = "pkgadd -d %s -n %s 2>&1" % [self[:source], self[:name]]

            self.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        end

        def query
            names = {
                "PKGINST" => :name,
                "NAME" => nil,
                "CATEGORY" => :category,
                "ARCH" => :platform,
                "VERSION" => :ensure,
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

            hash = {}

            # list out all of the packages
            open("| pkginfo -l %s 2>/dev/null" % self.name) { |process|
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
                            self.err "'pkginfo' returned invalid name %s" %
                                name
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

        def list
            packages = []
            hash = {}
            names = {
                "PKGINST" => :name,
                "NAME" => nil,
                "CATEGORY" => :category,
                "ARCH" => :platform,
                "VERSION" => :ensure,
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

        # we need package retrieval mechanisms before we can have package
        # installation mechanisms...
        #type.install = proc { |pkg|
        #    raise "installation not implemented yet"
        #}

        def remove
            cmd = "pkgrm -n %s 2>&1" % self.name
            output = %x{#{cmd}}
            if $? != 0
                raise Puppet::Error, "Removal of %s failed: %s" % [self.name, output]
            end
        end
    end
end
