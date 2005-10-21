# Define the different packaging systems.  Each package system is implemented
# in a module, which then gets used to individually extend each package object.
# This allows packages to exist on the same machine using different packaging
# systems.

require 'puppet/type/state'
require 'puppet/type/package/dpkg.rb'
require 'puppet/type/package/apt.rb'
require 'puppet/type/package/rpm.rb'
require 'puppet/type/package/yum.rb'
require 'puppet/type/package/sun.rb'

module Puppet
    class PackageError < Puppet::Error; end
    class State
        class PackageInstalled < Puppet::State
            @name = :install

            @doc = "What state the package should be in.  Specifying *true* will
                only result in a change if the package is not installed at all; use
                *latest* to keep the package (and, depending on the package system, its
                prerequisites) up to date.  Specifying *false* will uninstall the
                package if it is installed.  *true*/*false*/*latest*/``version``"

            # Override the parent method, because we've got all kinds of
            # funky definitions of 'in sync'.
            def insync?
                # Iterate across all of the should values, and see how they turn out.
                @should.each { |should|
                    case should
                    when :installed
                        unless @is == :notinstalled
                            return true
                        end
                    when :latest
                        latest = @parent.latest
                        if @is == latest
                            return true
                        else
                            Puppet.debug "latest %s is %s" % [@parent.name, latest]
                        end
                    when :notinstalled
                        if @is == :notinstalled
                            return true
                        end
                    when @is
                        return true
                    end
                }

                return false
            end

            # This retrieves the current state
            def retrieve
                unless defined? @is
                    @parent.retrieve
                end
            end

            def shouldprocess(value)
                # possible values are: true, false, and a version number
                case value
                when "latest":
                    unless @parent.respond_to?(:latest)
                        Puppet.err @parent.inspect
                        raise Puppet::Error,
                            "Package type %s does not support querying versions" %
                            @parent[:type]
                    end
                    return :latest
                when true, :installed:
                    return :installed
                when false, :notinstalled:
                    return :notinstalled
                else
                    # We allow them to set a should value however they want,
                    # but only specific package types will be able to use this
                    # value
                    return value
                end
            end

            def sync
                method = nil
                event = nil
                case @should[0]
                when :installed:
                    method = :install
                    event = :package_installed
                when :notinstalled:
                    method = :remove
                    event = :package_removed
                when :latest
                    if @is == :notinstalled
                        method = :install
                        event = :package_installed
                    else
                        method = :update
                        event = :package_updated
                    end
                else
                    unless ! @parent.respond_to?(:versionable?) or @parent.versionable?
                        Puppet.warning value
                        raise Puppet::Error,
                            "Package type %s does not support specifying versions" %
                            @parent[:type]
                    else
                        method = :install
                        event = :package_installed
                    end
                end

                if @parent.respond_to?(method)
                    begin
                    @parent.send(method)
                    rescue => detail
                        Puppet.err "Could not run %s: %s" % [method, detail.to_s]
                        raise
                    end
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
                Puppet::PackagingType::Yum,
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
                    when "fedora": @default = :yum
                    when "redhat": @default = :rpm
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
                type = hash["type"] || hash[:type] || self.class.default
                self.type2module(type)

                super

                unless @states.include?(:install)
                    Puppet.debug "Defaulting to installing a package"
                    self[:install] = true
                end

                unless @parameters.include?(:type)
                    self[:type] = self.class.default
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

            # Extend the package with the appropriate package type.
            def type2module(typename)
                if type = self.class.pkgtype(typename)
                    Puppet.debug "Extending to package type %s" % [type]
                    self.extend(type)
                else
                    raise Puppet::Error, "Invalid package type %s" % typename
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
