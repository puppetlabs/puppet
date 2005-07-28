#!/usr/local/bin/ruby -w

# $Id$

require 'puppet/type/state'
require 'puppet/fact'

module Puppet
    class PackageError < Puppet::Error; end
    class State
        class PackageInstalled < Puppet::State
            @name = :install

            @doc = "boolean flag for defining the package to be installed"

            def retrieve
                unless defined? @is
                    @parent.retrieve
                end

                # if the only requirement is that it's installed, then settle
                # for that
                if @should == true
                    if @is
                        @is = true
                    end
                end
            end

            def should=(value)
                # possible values are: true, false, and a version number
                if value == true or value == false or value =~ /^[0-9]/
                    @should = value
                else
                    raise Puppet::Error.new(
                        "Invalid install value %s" % value
                    )
                end
            end

            def sync
                type = @parent.pkgtype
                begin
                    if @should == false
                        type.remove(@parent)
                    else
                        type.install(@parent)
                    end
                rescue => detail
                    raise Puppet::Error.new(
                        "Could not install package %s: %s" % [@parent.name, detail]
                    )
                end

                if @should == false
                    return :package_removed
                else
                    return :package_installed
                end
            end
        end
    end

    class Type
        # packages are complicated because each package format has completely
        # different commands.  We need some way to convert specific packages
        # into the general package object...
        class Package < Type
            attr_reader :version, :pkgtype

            @states = [
                Puppet::State::PackageInstalled
            ]
            @parameters = [
                :name,
                :type,
                :instance,
                :status,
                :version,
                :category,
                :platform,
                :root,
                :vendor,
                :description
            ]

            @paramdoc[:name] = "..."
            @paramdoc[:type] = "..."
            @paramdoc[:instance] = "..."
            @paramdoc[:status] = "..."
            @paramdoc[:version] = "..."
            @paramdoc[:category] = "..."
            @paramdoc[:platform] = "..."
            @paramdoc[:root] = "..."
            @paramdoc[:vendor] = "..."
            @paramdoc[:description] = "..."

            @doc = "Allows control of package objects"
            @name = :package
            @namevar = :name
            @listed = false

            @allowedmethods = [:types]
            @@types = nil

            @@default = nil
            @@platform = nil

            class << self
                attr_reader :listed
            end

            def self.clear
                @listed = false
                super
            end

            def self.default
                if @@default.nil?
                    self.init
                end

                return @@default
            end

            def self.defaulttype
                return Puppet::PackagingType[self.default]
            end

            def self.init
                unless @@platform = Facter["operatingsystem"].value.downcase
                    raise Puppet::DevError(
                        "Must know platform for package management"
                    )
                end
                case @@platform
                when "sunos": @@default = :sunpkg
                when "linux":
                    case Facter["distro"].value.downcase
                    when "gentoo": raise "No support for gentoo yet"
                    when "debian": @@default = :apt
                    when "redhat", "fedora": @@default = :rpm
                    else
                        #raise "No default type for " + Puppet::Fact["distro"]
                        Puppet.warning "Using rpm as default type for %s" %
                            Facter["distro"].value
                        @@default = :rpm
                    end
                else
                    raise Puppet::Error.new(
                        "No default type for " + Puppet::Fact["operatingsystem"]
                    )
                end
            end

            def self.types(array)
                unless array.is_a?(Array)
                    array = [array]
                end
                @@types = array
                Puppet.debug "Types are %s" % array.join(" ")
            end

            def self.getpkglist
                if @@types.nil?
                    if @@default.nil?
                        self.init
                    end
                    @@types = [@@default]
                end

                list = @@types.collect { |type|
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
                    obj = self.new(:name => name)
                    hash.each { |var,value|
                        obj.addis(var,value)
                    }
                    return obj
                end
            end

            def self.pkgtype(pkgtype)
                if @typeary.length != @typehash.length
                    self.buildpkgtypehash
                end
                
                return @typehash[pkgtype]
            end

            def addis(state,value)
                if stateklass = self.class.validstate?(state)
                    @states[state] = stateklass.new(:parent => self)
                    @states[state].is = value
                elsif self.class.validparameter?(state)
                    self[state] = value
                else
                    raise Puppet::DevError.new("Invalid package state %s" % state)
                end

            end

            # okay, there are two ways that a package could be created...
            # either through the language, in which case the hash's values should
            # be set in 'should', or through comparing against the system, in which
            # case the hash's values should be set in 'is'
            def initialize(hash)
                unless hash.include?(:install) or hash.include?("install")
                    Puppet.debug "Defaulting to installing a package"
                    hash[:install] = true
                end

                super

                unless @parameters.include?(:type)
                    if @@default.nil?
                        self.class.init
                    end
                    self[:type] = @@default
                end
            end

            def retrieve
                unless pkgtype = Puppet::PackagingType[@parameters[:type]]
                    raise Puppet::DevError.new(
                        "No support for type %s" % @parameters[:type]
                    )
                end

                begin
                    hash = pkgtype.query(self)
                rescue => error
                    Puppet.err "Cannot install %s: %s" %
                        [self.name, error.to_s]

                    @states.delete(:install)
                end

                if hash.nil?
                    @states[:install].is = nil
                end

                hash.each { |name,value|
                    if self.class.validstate?(name)
                        if @states.include?(name)
                            @states[name].is = value
                        else
                            # silently ignore any returned states
                            # that we're not managing
                            # this is highly unlikely to happen
                            Puppet.info "%s missing state %s" %
                                [self.name, name]
                        end
                    elsif self.class.validparameter?(name)
                        self[name] = value
                    else
                        # silently ignore anything that's not a valid state
                        # or param
                    end
                }

                # now let them all handle things as necessary
                @states.each { |name, state|
                    state.retrieve
                }
            end

            def paramtype=(typename)
                @parameters[:type] = typename
                pkgtype = nil

                unless pkgtype = Puppet::PackagingType[typename]
                    raise Puppet::Error.new(
                        "Could not find package type %s" % typename
                    )
                end

                @pkgtype = pkgtype
            end
        end # Puppet::Type::Package
    end

    class PackagingType
        @params = [:list, :query, :remove, :install]
        attr_writer(*@params)

        class << self
            attr_reader :params
        end

        @@types = Hash.new(false)

        def PackagingType.[](name)
            if @@types.include?(name)
                return @@types[name]
            else
                Puppet.warning name.inspect
                Puppet.warning @@types.keys.collect { |key|
                    key.inspect
                }.join(" ")
                return nil
            end
        end

        # whether a package is installed or not
        def [](name)
            return @packages[name]
        end

        @params.each { |method|
            self.send(:define_method, method) { |pkg|
                # retrieve the variable
                var = eval("@" + method.id2name)
                if var.is_a?(Proc)
                    var.call(pkg)
                else
                    raise "only blocks are supported right now"
                end
            }
        }
        
        def initialize(name)
            if block_given?
                yield self
            end

            @packages = Hash.new(false)
            @@types[name] = self
        end

        def retrieve
            @packages.clear()

            @packages = self.list()
        end
    end

    PackagingType.new(:apt) { |type|
        type.query = proc { |pkg|
            packages = []

            # dpkg only prints as many columns as you have available
            # which means we don't get all of the info
            # stupid stupid
            oldcol = ENV["COLUMNS"]
            ENV["COLUMNS"] = "500"
            fields = [:desired, :status, :error, :name, :version, :description]

            hash = {}
            # list out all of the packages
            open("| dpkg -l %s 2>/dev/null" % pkg) { |process|
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
                    raise "failed to match dpkg line %s" % line
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
                # this isn't really correct, but we'll settle for it for now
                hash[:install] = nil
            end

            return hash
        }
        type.list = proc {
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
                        raise "failed to match dpkg line %s" % line
                    end
                }
            }
            ENV["COLUMNS"] = oldcol

            return packages
        }

        # we need package retrieval mechanisms before we can have package
        # installation mechanisms...
        type.install = proc { |pkg|
            cmd = "apt-get install %s" % pkg

            Puppet.info "Executing %s" % cmd.inspect
            output = %x{#{cmd} 2>&1}

            unless $? == 0
                raise Puppet::PackageError.new(output)
            end
        }

        type.remove = proc { |pkg|
            cmd = "dpkg -r %s" % pkg.name
            output = %x{#{cmd}}
            if $? != 0
                raise Puppet::PackageError.new(output)
            end
        }
    }

    PackagingType.new(:rpm) { |type|
        type.list = proc {
            packages = []

            # dpkg only prints as many columns as you have available
            # which means we don't get all of the info
            # stupid stupid
            oldcol = ENV["COLUMNS"]
            ENV["COLUMNS"] = "500"

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
            ENV["COLUMNS"] = oldcol

            return packages
        }

        # we need package retrieval mechanisms before we can have package
        # installation mechanisms...
        #type.install = proc { |pkg|
        #    raise "installation not implemented yet"
        #}

        type.remove = proc { |pkg|
            cmd = "rpm -e %s" % pkg.name
            output = %x{#{cmd}}
            if $? != 0
                raise output
            end
        }
    }

    PackagingType.new(:sunpkg) { |type|
        type.list = proc {
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
                # we're using the long listing, so each line is a separate piece
                # of information
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
        }

        # we need package retrieval mechanisms before we can have package
        # installation mechanisms...
        #type.install = proc { |pkg|
        #    raise "installation not implemented yet"
        #}

        type.remove = proc { |pkg|
            cmd = "pkgrm -n %s" % pkg.name
            output = %x{#{cmd}}
            if $? != 0
                raise output
            end
        }
    }

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
