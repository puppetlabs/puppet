module Puppet
    module PackagingType
        module Sun
            def query
                names = {
                    "PKGINST" => :name,
                    "NAME" => nil,
                    "CATEGORY" => :category,
                    "ARCH" => :platform,
                    "VERSION" => :install,
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
                    "VERSION" => :install,
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
                open("| pkginfo -l") { |process|
                    # we're using the long listing, so each line is a separate
                    # piece of information
                    process.each { |line|
                        case line
                        when /^$/:
                            packages.push Puppet::Type::Package.installedpkg(hash)
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
                cmd = "pkgrm -n %s" % self.name
                output = %x{#{cmd}}
                if $? != 0
                    raise output
                end
            end
        end
    end
end
