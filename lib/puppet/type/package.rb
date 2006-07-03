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
            sun) cannot.  For those package formats that cannot retrieve
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
                unless parenttype = pkgtype(parent)
                    raise Puppet::DevError,
                        "No parent type %s for package type %s" %
                        [parent, name]
                end
                mod.send(:include, parenttype)
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

            class << mod
                include Puppet::Util
            end

            # It's at least conceivable that a module would not define this method
            # "module_function" makes the :list method private, so if the parent
            # method also called module_function, then it's already private
            if mod.public_method_defined? :list or mod.private_method_defined? :list
                mod.send(:module_function, :list)
            end

            # Add it to our list
            @pkgtypes[name] = mod

            # And mark it as a valid type
            unless defined? @typeparam
                @typeparam = @parameters.find { |p| p.name == :type }

                unless @typeparam
                    Puppet.warning @parameters.inspect
                    raise Puppet::DevError, "Could not package type parameter"
                end
            end
            @typeparam.newvalues(name)
        end

        # Autoload the package types, if they're not already defined.
        def self.pkgtype(name)
            #name = name[0] if name.is_a? Array
            name = name.intern if name.is_a? String
            @pkgtypes ||= {}
            unless @pkgtypes.include? name
                begin
                    require "puppet/type/package/#{name}"

                    unless @pkgtypes.include? name
                        Puppet.warning @pkgtypes.keys
                        raise Puppet::DevError,
                            "Loaded %s but pkgtype was not created" % name.inspect
                    end
                rescue LoadError
                    raise Puppet::Error, "Could not load package type %s" % name
                end
            end
            @pkgtypes[name]
        end

        def self.pkgtypes
            @pkgtypes.keys
        end

        ensurable do
            desc "What state the package should be in.
                *latest* only makes sense for those packaging formats that can
                retrieve new packages on their own and will throw an error on
                those that cannot."

            attr_accessor :latest

            newvalue(:present) do
                @parent.install
            end

            newvalue(:absent) do
                @parent.uninstall
            end

            # Alias the 'present' value.
            aliasvalue(:installed, :present)

            newvalue(:latest) do
                unless @parent.respond_to?(:latest)
                    self.fail(
                        "Package type %s does not support specifying 'latest'" %
                        @parent[:type]
                    )
                end

                # Because yum always exits with a 0 exit code, there's a retrieve
                # in the "install" method.  So, check the current state now,
                # to compare against later.
                current = self.is
                begin
                    @parent.update
                rescue => detail
                    self.fail "Could not update: %s" % detail
                end

                if current == :absent
                    return :package_created
                else
                    return :package_changed
                end
            end

            defaultto :installed

            # Override the parent method, because we've got all kinds of
            # funky definitions of 'in sync'.
            def insync?
                @should ||= []

                @latest = nil unless defined? @latest
                @lateststamp ||= (Time.now.to_i - 1000)
                # Iterate across all of the should values, and see how they
                # turn out.
                @should.each { |should|
                    case should
                    when :present
                        unless @is == :absent
                            return true
                        end
                    when :latest
                        # Short-circuit packages that are not present
                        if @is == :absent
                            return false
                        end

                        unless @parent.respond_to?(:latest)
                            self.fail(
                                "Package type %s does not support specifying 'latest'" %
                                @parent[:type]
                            )
                        end

                        # Don't run 'latest' more than about every 5 minutes
                        if @latest and ((Time.now.to_i - @lateststamp) / 60) < 5
                            #self.debug "Skipping latest check"
                        else
                            begin
                                @latest = @parent.latest
                                @lateststamp = Time.now.to_i
                            rescue => detail
                                self.fail "Could not get latest version: %s" % detail
                            end
                        end
                        case @is
                        when @latest:
                            return true
                        when :present:
                            if @parent[:version] == @latest
                                return true
                            else
                                self.debug "our version is %s and latest is %s" %
                                    [@parent[:version], @latest]
                            end
                        else
                            self.debug "@is is %s, latest %s is %s" %
                                [@is, @parent.name, @latest]
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
                @parent.retrieve
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
            a common name to packages:

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
            desc "The package format.  You will seldom need to specify this --
                Puppet will discover the appropriate format for your platform."

            defaultto { @parent.class.default }


            validate do |value|
                value = value[0] if value.is_a? Array
                unless @parent.class.pkgtype(value)
                    raise ArgumentError, "Invalid package type '%s'" % value
                end
            end


            munge do |type|
                type = type[0] if type.is_a? Array
                if type.is_a? String
                    type = type.intern
                end
                @parent.type2module(type)
                type
            end

        end

        newparam(:source) do
            desc "From where to retrieve the package."

            validate do |value|
                unless value =~ /^#{File::SEPARATOR}/ or value =~ /\w+:\/\//
                    self.fail(
                        "Package sources must be fully qualified files or URLs, depending on the platform."
                    )
                end
            end
        end
        newparam(:instance) do
            desc "A read-only parameter set by the package."
        end
        newparam(:status) do
            desc "A read-only parameter set by the package."
        end

        newparam(:adminfile) do
            desc "A file containing package defaults for installing packages.
                This is currently only used on Solaris.  The value will be
                validated according to system rules, which in the case of
                Solaris means that it should either be a fully qualified path
                or it should be in /var/sadm/install/admin."
        end

        newparam(:responsefile) do
            desc "A file containing any necessary answers to questions asked by
                the package.  This is currently only used on Solaris.  The
                value will be validated according to system rules, but it should
                generally be a fully qualified path."
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

        autorequire(:file) do
            autos = []
            [:responsefile, :adminfile].each { |param|
                if val = self[param]
                    autos << val
                end
            }

            if source = self[:source]
                if source =~ /^#{File::SEPARATOR}/
                    autos << source
                end
            end
            autos
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
            when "solaris": @default = :sun
            when "gentoo":
                Puppet.notice "No support for gentoo yet"
                @default = nil
            when "debian": @default = :apt
            when "centos": @default = :rpm
            when "fedora": @default = :yum
            when "redhat": @default = :rpm
            when "freebsd": @default = :ports
            when "openbsd": @default = :openbsd
            when "darwin": @default = :apple
            else
                if Facter["kernel"] == "Linux"
                    Puppet.warning "Defaulting to RPM for %s" %
                        Facter["operatingsystem"].value
                    @default = :rpm
                else
                    Puppet.warning "No default package system for %s" %
                        Facter["operatingsystem"].value
                    @default = nil
                end
            end
        end

        # Create a new package object from listed information
        def self.installedpkg(hash)
            unless hash.include? :type
                raise Puppet::DevError, "Got installed package with no type"
            end
            # this is from code, so we don't have to do as much checking
            name = hash[:name]
            hash.delete(:name)

            object = self[name] || self.create(:name => name)
            object.setparams(hash)

            return object
        end

        # List all package instances
        def self.list
            pkgtype(default).list()

            self.collect do |pkg|
                pkg
            end
        end

        # Iterate across all packages of a given type and mark them absent
        # if they are not in the list
        def self.markabsent(pkgtype, packages)
            # Mark any packages we didn't find as absent
            self.each do |pkg|
                next unless packages[:type] == pkgtype
                unless packages.include? pkg
                    pkg.is = [:ensure, :absent] 
                end
            end
        end

        # This only exists for testing.
        def clear
            @states[:ensure].latest = nil
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
                if hash == :listed # Mmmm, hackalicious
                    return
                end
                hash.each { |param, value|
                    unless self.class.validattr?(param)
                        hash.delete(param)
                    end
                }

                setparams(hash)
            else
                # Else just mark all of the states absent.
                self.class.validstates.each { |name|
                    self.is = [name, :absent]
                }
            end
        end

        # Set all of the params' "is" value.  Most are parameters, but some
        # are states.
        def setparams(hash)
            # Everything on packages is a parameter except :ensure
            hash.each { |param, value|
                if self.class.attrtype(param) == :state
                    self.is = [param, value]
                else
                    self[param] = value
                end
            }
        end

        # Extend the package with the appropriate package type.
        def type2module(typename)
            if type = self.class.pkgtype(typename)
                self.extend(type)

                return type
            else
                self.fail "Invalid package type %s" % typename
            end
        end
    end # Puppet.type(:package)
end

# $Id$
