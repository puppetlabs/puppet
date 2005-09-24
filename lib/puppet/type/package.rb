# Define the different packaging systems.  Each package system is implemented
# in a module, which then gets used to individually extend each package object.
# This allows packages to exist on the same machine using different packaging
# systems.

require 'puppet/type/state'

module Puppet
    class PackageError < Puppet::Error; end

    module PackagingType
        # The packaging system for Debian systems.
        module DPKG
            def query
                packages = []

                # dpkg only prints as many columns as you have available
                # which means we don't get all of the info
                # stupid stupid
                oldcol = ENV["COLUMNS"]
                ENV["COLUMNS"] = "500"
                fields = [:desired, :status, :error, :name, :version, :description]

                hash = {}
                # list out our specific package
                open("| dpkg -l %s 2>/dev/null" % self.name) { |process|
                    # our regex for matching dpkg output
                    regex = %r{^(.)(.)(.)\s(\S+)\s+(\S+)\s+(.+)$}

                    # we only want the last line
                    lines = process.readlines
                    # we've got four header lines, so we should expect all of those
                    # plus our output
                    if lines.length < 5
                        return nil
                    end

                    line = lines[-1]

                    if match = regex.match(line)
                        fields.zip(match.captures) { |field,value|
                            hash[field] = value
                        }
                        #packages.push Puppet::Type::Package.installedpkg(hash)
                    else
                        raise Puppet::DevError,
                            "failed to match dpkg line %s" % line
                    end
                }
                ENV["COLUMNS"] = oldcol

                if hash[:error] != " "
                    raise Puppet::PackageError.new(
                        "Package %s, version %s is in error state: %s" %
                            [hash[:name], hash[:install], hash[:error]]
                    )
                end

                if hash[:status] == "i"
                    hash[:install] = hash[:version]
                else
                    hash[:install] = :notinstalled
                end

                return hash
            end

            def list
                packages = []

                # dpkg only prints as many columns as you have available
                # which means we don't get all of the info
                # stupid stupid
                oldcol = ENV["COLUMNS"]
                ENV["COLUMNS"] = "500"

                # list out all of the packages
                open("| dpkg -l") { |process|
                    # our regex for matching dpkg output
                    regex = %r{^(\S+)\s+(\S+)\s+(\S+)\s+(.+)$}
                    fields = [:status, :name, :install, :description]
                    hash = {}

                    5.times { process.gets } # throw away the header

                    # now turn each returned line into a package object
                    process.each { |line|
                        if match = regex.match(line)
                            hash.clear

                            fields.zip(match.captures) { |field,value|
                                hash[field] = value
                            }
                            packages.push Puppet::Type::Package.installedpkg(hash)
                        else
                            raise Puppet::DevError,
                                "Failed to match dpkg line %s" % line
                        end
                    }
                }
                ENV["COLUMNS"] = oldcol

                return packages
            end

            def remove
                cmd = "dpkg -r %s" % self.name
                output = %x{#{cmd} 2>&1}
                if $? != 0
                    raise Puppet::PackageError.new(output)
                end
            end
        end
        
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
        
        module RPM
            def query
                fields = {
                    :name => "NAME",
                    :install => "VERSION",
                    :description => "DESCRIPTION"
                }

                cmd = "rpm -q --qf '%s\n'" %
                    %w{NAME VERSION DESCRIPTION}.collect { |str|
                        "%{#{str}}"
                    }.join(" ")

                # list out all of the packages
                str = %x{#{cmd} 2>/dev/null}.chomp

                if $? != 0
                    return nil
                end

                regex = %r{^(\S+)\s+(\S+)\s+(.+)}
                fields = [:name, :install, :description]
                hash = {}
                if match = regex.match(str)
                    fields.zip(match.captures) { |field,value|
                        hash[field] = value
                    }
                else
                    raise Puppet::DevError,
                        "Failed to match rpm output '%s'" %
                        str
                end

                return hash
            end

            def list
                packages = []

                # list out all of the packages
                open("| rpm -q -a --qf '%{NAME} %{VERSION}\n'") { |process|
                    # our regex for matching dpkg output
                    regex = %r{^(\S+)\s+(\S+)}
                    fields = [:name, :install]
                    hash = {}

                    # now turn each returned line into a package object
                    process.each { |line|
                        if match = regex.match(line)
                            hash.clear

                            fields.zip(match.captures) { |field,value|
                                hash[field] = value
                            }
                            packages.push Puppet::Type::Package.installedpkg(hash)
                        else
                            raise "failed to match rpm line %s" % line
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
                cmd = "rpm -e %s" % self.name
                output = %x{#{cmd}}
                if $? != 0
                    raise output
                end
            end
        end
        
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
                                Puppet.err "'pkginfo' returned invalid name %s" %
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

    class State
        class PackageInstalled < Puppet::State
            @name = :install

            @doc = "What state the package should be in.
                *true*/*false*/``version``"

            def retrieve
                unless defined? @is
                    @parent.retrieve
                end
            end

            def should=(value)
                # possible values are: true, false, and a version number
                case value
                #when true, /^[0-9]/:
                when true:
                    @should = value
                when false:
                    @should = :notinstalled
                else
                    raise Puppet::Error.new(
                        "Invalid install value %s" % value
                    )
                end
            end

            def sync
                method = nil
                event = nil
                case @should
                when true:
                    method = :install
                    event = :package_installed
                when :notinstalled:
                    method = :remove
                    event = :package_removed
                else
                    raise Puppet::Error, "Invalid should value %s" % @should
                end

                if @parent.respond_to?(method)
                    @parent.send(method)
                else
                    raise Puppet::Error, "Packages of type %s do not support %s" %
                        [@parent[:type], method]
                end

                return event
            end
        end
    end

    class Type
        # packages are complicated because each package format has completely
        # different commands.  We need some way to convert specific packages
        # into the general package object...
        class Package < Type
            attr_reader :version, :pkgtype

            @pkgtypes = [
                Puppet::PackagingType::APT,
                Puppet::PackagingType::DPKG,
                Puppet::PackagingType::RPM,
                Puppet::PackagingType::Sun
            ]

            @pkgtypehash = {}

            # Now collect the name of each type and store it thusly
            @pkgtypes.each { |type|
                if type.respond_to?(:typename)
                    @pkgtypehash[type.typename] = type
                else
                    name = type.to_s.sub(/.+::/, '').downcase.intern
                    @pkgtypehash[name] = type
                end
            }

            @states = [
                Puppet::State::PackageInstalled
            ]
                #:version,
            @parameters = [
                :name,
                :type,
                :instance,
                :status,
                :category,
                :platform,
                :root,
                :vendor,
                :description
            ]

            @paramdoc[:name] = "The package name."
            @paramdoc[:type] = "The package format.  Currently supports " +
                @pkgtypes.collect {|t|
                    "``" + t.name.to_s + "``"
                }.join(", ") + "."
            @paramdoc[:instance] = "A read-only parameter set by the package."
            @paramdoc[:status] = "A read-only parameter set by the package."
            #@paramdoc[:version] = "A read-only parameter set by the package."
            @paramdoc[:category] = "A read-only parameter set by the package."
            @paramdoc[:platform] = "A read-only parameter set by the package."
            @paramdoc[:root] = "A read-only parameter set by the package."
            @paramdoc[:vendor] = "A read-only parameter set by the package."
            @paramdoc[:description] = "A read-only parameter set by the package."

            @doc = "Manage packages.  Eventually will support retrieving packages
                from remote sources but currently only supports packaging
                systems which can retrieve their own packages, like ``apt``."
            @name = :package
            @namevar = :name
            @listed = false

            @allowedmethods = [:types]

            @default = nil
            @platform = nil

            class << self
                attr_reader :listed
            end

            def self.clear
                @listed = false
                super
            end

            # Cache and return the default package type for our current
            # platform.
            def self.default
                if @default.nil?
                    self.init
                end

                return @default
            end

            # Figure out what the default package type is for the platform
            # on which we're running.
            def self.init
                unless @platform = Facter["operatingsystem"].value.downcase
                    raise Puppet::DevError.new(
                        "Must know platform for package management"
                    )
                end
                case @platform
                when "sunos": @default = :sun
                when "linux":
                    case Facter["distro"].value.downcase
                    when "gentoo":
                        Puppet.notice "No support for gentoo yet"
                        @default = nil
                    when "debian": @default = :apt
                    when "redhat", "fedora": @default = :rpm
                    else
                        Puppet.warning "Using rpm as default type for %s" %
                            Facter["distro"].value
                        @default = :rpm
                    end
                else
                    @default = nil
                end
            end

            def self.getpkglist
                if @types.nil?
                    if @default.nil?
                        self.init
                    end
                    @types = [@default]
                end

                list = @types.collect { |type|
                    if typeobj = Puppet::PackagingType[type]
                        # pull all of the objects
                        typeobj.list
                    else
                        raise "Could not find package type '%s'" % type
                    end
                }.flatten
                @listed = true
                return list
            end

            def Package.installedpkg(hash)
                # this is from code, so we don't have to do as much checking
                name = hash[:name]
                hash.delete(:name)

                # if it already exists, modify the existing one
                if object = Package[name]
                    states = {}
                    object.eachstate { |state|
                        Puppet.debug "Adding %s" % state.name.inspect
                        states[state.name] = state
                    }
                    hash.each { |var,value|
                        if states.include?(var)
                            Puppet.debug "%s is a set state" % var.inspect
                            states[var].is = value
                        else
                            Puppet.debug "%s is not a set state" % var.inspect
                            if object[var] and object[var] != value
                                Puppet.warning "Overriding %s => %s on %s with %s" %
                                    [var,object[var],name,value]
                            end

                            #object.state(var).is = value

                            # swap the values if we're a state
                            if states.include?(var)
                                Puppet.debug "Swapping %s because it's a state" % var
                                states[var].is = value
                                states[var].should = nil
                            else
                                Puppet.debug "%s is not a state" % var.inspect
                                Puppet.debug "States are %s" % states.keys.collect { |st|
                                    st.inspect
                                }.join(" ")
                            end
                        end
                    }
                    return object
                else # just create it
                    obj = self.create(:name => name)
                    hash.each { |var,value|
                        obj.addis(var,value)
                    }
                    return obj
                end
            end

            # Retrieve a package type by name; names are symbols.
            def self.pkgtype(pkgtype)
                if pkgtype.is_a?(String)
                    pkgtype = pkgtype.intern
                end
                return @pkgtypehash[pkgtype]
            end

            # okay, there are two ways that a package could be created...
            # either through the language, in which case the hash's values should
            # be set in 'should', or through comparing against the system, in which
            # case the hash's values should be set in 'is'
            def initialize(hash)
                super

                unless @states.include?(:install)
                    Puppet.debug "Defaulting to installing a package"
                    self[:install] = true
                end

                unless @parameters.include?(:type)
                    self[:type] = self.class.default
                end
            end

            # Set the package type parameter.  Looks up the corresponding
            # module and then extends the 'install' state.
            def paramtype=(typename)
                if type = self.class.pkgtype(typename)
                    Puppet.debug "Extending %s with %s" % [self.name, type]
                    self.extend(type)
                    @parameters[:type] = type
                else
                    raise Puppet::Error, "Invalid package type %s" % typename
                end
            end

            def retrieve
                if hash = self.query
                    hash.each { |param, value|
                        unless self.class.validarg?(param)
                            hash.delete(param)
                        end
                    }

                    hash.each { |param, value|
                        self.is = [param, value]
                    }
                else
                    self.class.validstates.each { |name, state|
                        self.is = [name, :notinstalled]
                    }
                end
            end
        end # Puppet::Type::Package
    end

    # this is how we retrieve packages
    class PackageSource
        attr_accessor :uri
        attr_writer :retrieve

        @@sources = Hash.new(false)

        def PackageSource.get(file)
            type = file.sub(%r{:.+},'')
            source = nil
            if source = @@sources[type]
                return source.retrieve(file)
            else
                raise "Unknown package source: %s" % type
            end
        end

        def initialize(name)
            if block_given?
                yield self
            end

            @@sources[name] = self
        end

        def retrieve(path)
            @retrieve.call(path)
        end

    end

    PackageSource.new("file") { |obj|
        obj.retrieve = proc { |path|
            # this might not work for windows...
            file = path.sub(%r{^file://},'')

            if FileTest.exists?(file)
                return file
            else
                raise "File %s does not exist" % file
            end
        }
    }
end

# $Id$
