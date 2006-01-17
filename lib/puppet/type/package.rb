# Define the different packaging systems.  Each package system is implemented
# in a module, which then gets used to individually extend each package object.
# This allows packages to exist on the same machine using different packaging
# systems.

require 'puppet/type/state'

module Puppet
    class PackageError < Puppet::Error; end
    newtype(:package) do
        @doc = "Manage packages.  There is a basic dichotomy in package
            support right now:  Some package types (e.g., yum and apt) can
            retrieve their own package files, while others (e.g., rpm and
            sunpkg) cannot.  For those package formats that cannot retrieve
            their own files, you can use the ``source`` parameter to point to
            the correct file.

            Puppet will automatically guess the packaging format that you are
            using based on the platform you are on, but you can override it
            using the ``type`` parameter; obviously, if you specify that you
            want to use ``rpm`` then the ``rpm`` tools must be available."

        # Create a new packaging type
        def self.newpkgtype(name, parent = nil, &block)
            @pkgtypes ||= {}

            if @pkgtypes.include?(name)
                raise Puppet::DevError, "Package type %s already defined" % name
            end

            mod = Module.new
            const_set("PkgType" + name.to_s.capitalize,mod)

            # Add our parent, if it exists
            if parent
                unless @pkgtypes.include?(parent)
                    raise Puppet::DevError,
                        "No parent type %s for package type %s" %
                        [parent, name]
                end
                mod.send(:include, @pkgtypes[parent])
            end

            # And now define the support methods
            code = %{
                def self.name
                    "#{name}"
                end

                def self.to_s
                    "PkgType(#{name})"
                end

                def pkgtype
                    "#{name}"
                end
            }

            mod.module_eval(code)

            mod.module_eval(&block)

            @pkgtypes[name] = mod
        end

        def self.pkgtype(name)
            @pkgtypes[name]
        end

        def self.pkgtypes
            @pkgtypes.keys
        end

        ensurable do
            desc "What state the package should be in.  The primary options
                are *installed* (also called *present*), *uninstalled* (also
                called *absent*), and *latest*.  *latest* only makes sense for
                those packaging formats that can retrieve new packages on
                their own."

            #munge do |value|
            #    # possible values are: true, false, and a version number
            #    case value
            #    when "latest":
            #        unless @parent.respond_to?(:latest)
            #            self.err @parent.inspect
            #            raise Puppet::Error,
            #                "Package type %s cannot install later versions" %
            #                @parent[:type].name
            #        end
            #        return :latest
            #    when true, :present:
            #        return :present
            #    when false, :absent:
            #        return :absent
            #    else
            #        # We allow them to set a should value however they want,
            #        # but only specific package types will be able to use this
            #        # value
            #        return value
            #    end
            #end

            newvalue(:present) do
                @parent.install
            end

            newvalue(:absent) do
                @parent.uninstall
            end

            # Alias the 'present' value.
            aliasvalue(:installed, :present)
            #newvalue(:installed) do
            #    self.set(:present)
            #end

            newvalue(:latest) do
                @parent.update

                if self.is == :absent
                    return :package_created
                else
                    return :package_changed
                end
            end

            # Override the parent method, because we've got all kinds of
            # funky definitions of 'in sync'.
            def insync?
                @should ||= []
                # Iterate across all of the should values, and see how they
                # turn out.
                @should.each { |should|
                    case should
                    when :present
                        unless @is == :absent
                            return true
                        end
                    when :latest
                        latest = @parent.latest
                        case @is
                        when latest:
                            return true
                        when :present:
                            if @parent[:version] == latest
                                return true
                            end
                        else
                            self.debug "@is is %s, latest %s is %s" %
                                [@is, @parent.name, latest]
                        end
                    when :absent
                        if @is == :absent
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
                #unless defined? @is
                @parent.retrieve
                #end
            end

            def sync
                value = self.should
                unless value.is_a?(Symbol)
                    value = value.intern
                end
                # If we're a normal value, then just pass to the parent method
                if self.class.values.include?(value)
                    #self.info "setting %s" % value
                    super
                else
                    #self.info "updating from %s" % value
                    @parent.update
                end
            end
        end

        # Packages are complicated because each package format has completely
        # different commands.
        attr_reader :pkgtype

        newparam(:name) do
            desc "The package name.  This is the name that the packaging
            system uses internally, which is sometimes (especially on Solaris)
            a name that is basically useless to humans.  If you want to
            abstract package installation, then you can use aliases to provide
            a common name to packages::

                # In the 'openssl' class
                $ssl = $operationgsystem ? {
                    solaris => SMCossl,
                    default => openssl
                }

                # It is not an error to set an alias to the same value as the
                # object name.
                package { $ssl:
                    ensure => installed,
                    alias => openssl
                }

                . etc. .

                $ssh = $operationgsystem ? {
                    solaris => SMCossh,
                    default => openssh
                }

                # Use the alias to specify a dependency, rather than
                # having another selector to figure it out again.
                package { $ssh:
                    ensure => installed,
                    alias => openssh,
                    require => package[openssl]
                }
            
            "
            isnamevar
        end

        newparam(:type) do
            desc "The package format.  You will seldom need to specify this -- Puppet
                will discover the appropriate format for your platform."

            defaultto { @parent.class.default }

            # We cannot log in this routine, because this gets called before
            # there's a name for the package.
            munge do |type|
                @parent.type2module(type)
            end
        end

        newparam(:source) do
            desc "From where to retrieve the package."

            validate do |value|
                unless value =~ /^#{File::SEPARATOR}/ or value =~ /\w+:\/\//
                    raise Puppet::Error,
                        "Package sources must be fully qualified files or URLs, depending on the platform."
                end
            end
        end
        newparam(:instance) do
            desc "A read-only parameter set by the package."
        end
        newparam(:status) do
            desc "A read-only parameter set by the package."
        end

        # FIXME Version is screwy -- most package systems can't specify a
        # version, but people will definitely want to query versions, so
        # it almost seems like versions should be a read-only state,
        # supporting syncing only in certain cases.
        newparam(:version) do
            desc "For some platforms this is a read-only parameter set by the
                package, but for others, setting this parameter will cause
                the package of that version to be installed.  It just depends
                on the features of the packaging system."

#            validate do |value|
#                unless @parent.respond_to?(:versionable?) and @parent.versionable?
#                    raise Puppet::Error,
#                        "Package type %s does not support specifying versions." %
#                            @parent.pkgtype
#                end
#            end
        end
        newparam(:category) do
            desc "A read-only parameter set by the package."
        end
        newparam(:platform) do
            desc "A read-only parameter set by the package."
        end
        newparam(:root) do
            desc "A read-only parameter set by the package."
        end
        newparam(:vendor) do
            desc "A read-only parameter set by the package."
        end
        newparam(:description) do
            desc "A read-only parameter set by the package."
        end
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
            when "solaris": @default = :sunpkg
            when "gentoo":
                Puppet.notice "No support for gentoo yet"
                @default = nil
            when "debian": @default = :apt
            when "fedora": @default = :yum
            when "redhat": @default = :rpm
            when "openbsd": @default = :bsd
            else
                if Facter["kernel"] == "Linux"
                    Puppet.warning "Defaulting to RPM for %s" %
                        Facter["operatingsystem"].value
                    @default = nil
                else
                    Puppet.warning "No default package system for %s" %
                        Facter["operatingsystem"].value
                    @default = nil
                end
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

        def self.installedpkg(hash)
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

        # The 'query' method returns a hash of info if the package
        # exists and returns nil if it does not.
        def exists?
            self.query
        end

        # okay, there are two ways that a package could be created...
        # either through the language, in which case the hash's values should
        # be set in 'should', or through comparing against the system, in which
        # case the hash's values should be set in 'is'
        def initialize(hash)
            self.initvars
            type = nil
            [:type, "type"].each { |label|
                if hash.include?(label)
                    type = hash[label]
                    hash.delete(label)
                end
            }
            if type
                self[:type] = type
            else
                self.setdefaults(:type)
            end

            super

            #unless @states.include?(:ensure)
            #    self.debug "Defaulting to installing a package"
            #    self[:ensure] = true
            #end

            unless @parameters.include?(:type)
                self[:type] = self.class.default
            end
        end

        def retrieve
            # If the package is installed, then retrieve all of the information
            # about it and set it appropriately.
            #@states[:ensure].retrieve
            if hash = self.query
                hash.each { |param, value|
                    unless self.class.validattr?(param)
                        hash.delete(param)
                    end
                }

                hash.each { |param, value|
                    self.is = [param, value]
                }
            else
                # Else just mark all of the states absent.
                self.class.validstates.each { |name|
                    self.is = [name, :absent]
                }
            end
        end

        # Extend the package with the appropriate package type.
        def type2module(typename)
            if type = self.class.pkgtype(typename)
                self.extend(type)

                return type
            else
                raise Puppet::Error, "Invalid package type %s" % typename
            end
        end
    end # Puppet.type(:package)

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

# The order these are loaded is important.
require 'puppet/type/package/dpkg.rb'
require 'puppet/type/package/apt.rb'
require 'puppet/type/package/rpm.rb'
require 'puppet/type/package/yum.rb'
require 'puppet/type/package/sun.rb'
require 'puppet/type/package/bsd.rb'

# $Id$
