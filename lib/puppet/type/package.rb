# Define the different packaging systems.  Each package system is implemented
# in a module, which then gets used to individually extend each package object.
# This allows packages to exist on the same machine using different packaging
# systems.

require 'puppet/type/property'

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

        ensurable do
            desc "What state the package should be in.
                *latest* only makes sense for those packaging formats that can
                retrieve new packages on their own and will throw an error on
                those that cannot.  For those packaging systems that allow you
                to specify package versions, specify them here."

            attr_accessor :latest

            newvalue(:present, :event => :package_installed) do
                provider.install
            end

            newvalue(:absent, :event => :package_removed) do
                provider.uninstall
            end

            # Alias the 'present' value.
            aliasvalue(:installed, :present)

            newvalue(:latest) do
                unless provider.respond_to?(:latest)
                    self.fail(
                        "Package provider %s does not support specifying 'latest'" %
                        @parent[:provider]
                    )
                end

                # Because yum always exits with a 0 exit code, there's a retrieve
                # in the "install" method.  So, check the current state now,
                # to compare against later.
                current = self.is
                begin
                    provider.update
                rescue => detail
                    self.fail "Could not update: %s" % detail
                end

                if current == :absent
                    :package_installed
                else
                    :package_changed
                end
            end

            newvalue(/./) do
                unless provider.versionable?
                    self.fail(
                        "Package provider %s does not support specifying versions" %
                        @parent[:provider]
                     )
                end
                begin
                    provider.install
                rescue => detail
                    self.fail "Could not update: %s" % detail
                end

                if self.is == :absent
                    :package_installed
                else
                    :package_changed
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

                        unless provider.respond_to?(:latest)
                            self.fail(
                                "Package type %s does not support specifying 'latest'" %
                                @parent[:provider]
                            )
                        end

                        # Don't run 'latest' more than about every 5 minutes
                        if @latest and ((Time.now.to_i - @lateststamp) / 60) < 5
                            #self.debug "Skipping latest check"
                        else
                            begin
                                @latest = provider.latest
                                @lateststamp = Time.now.to_i
                            rescue => detail
                                self.fail "Could not get latest version: %s" % detail
                            end
                        end

                        case @is
                        when @latest:
                            return true
                        when :present:
                            # This will only happen on retarded packaging systems
                            # that can't query versions.
                            return true
                        else
                            self.debug "@is is %s, latest %s is %s" %
                                [@is.inspect, @parent.name, @latest.inspect]
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
                @is = @parent.retrieve
            end
        end

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

        newparam(:source) do
            desc "Where to find the actual package.  This must be a local file
                (or on a network file system) or a URL that your specific
                packaging type understands; Puppet will not retrieve files for you."

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

        newparam(:type) do
            desc "Deprecated form of ``provider``."

            munge do |value|
                warning "'type' is deprecated; use 'provider' instead"
                @parent[:provider] = value

                @parent[:provider]
            end
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

        newparam(:configfiles) do
            desc "Whether configfiles should be kept or replaced.  Most packages
                types do not support this parameter."

            defaultto :keep

            newvalues(:keep, :replace)
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

        newparam(:allowcdrom) do
            desc "Tells apt to allow cdrom sources in the sources.list file.
                Normally apt will bail if you try this."

            newvalues(:true, :false)
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

        class << self
            attr_reader :listed
        end

        def self.clear
            @listed = false
            super
        end

        # Create a new package object from listed information
        def self.installedpkg(hash)
            unless hash.include? :provider
                raise Puppet::DevError, "Got installed package with no provider"
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
            # XXX For now, just list the default provider, but we should list
            # all suitables or something, but we need to not list a parent
            # type if a child type gets listed.
            #suitableprovider.each do |provider|
            #    p provider.name
            #    provider.list
            #end

            defaultprovider.list

            self.collect do |pkg|
                pkg
            end
        end

        # Iterate across all packages of a given type and mark them absent
        # if they are not in the list
        def self.markabsent(pkgtype, packages)
            # Mark any packages we didn't find as absent
            self.each do |pkg|
                next unless packages[:provider] == pkgtype
                unless packages.include? pkg
                    pkg.is = [:ensure, :absent] 
                end
            end
        end

        # This only exists for testing.
        def clear
            if obj = @parameters[:ensure]
                obj.latest = nil
            end
        end

        # The 'query' method returns a hash of info if the package
        # exists and returns nil if it does not.
        def exists?
            @provider.query
        end

        # okay, there are two ways that a package could be created...
        # either through the language, in which case the hash's values should
        # be set in 'should', or through comparing against the system, in which
        # case the hash's values should be set in 'is'
        def initialize(hash)
            self.initvars
            type = nil
            [:provider, "use"].each { |label|
                if hash.include?(label)
                    type = hash[label]
                    hash.delete(label)
                end
            }
            if type
                self[:provider] = type
            else
                self.setdefaults(:provider)
            end

            super

            unless @parameters.include?(:provider)
                raise Puppet::DevError, "No package type set"
            end
        end

        def retrieve
            # If the package is installed, then retrieve all of the information
            # about it and set it appropriately.
            if hash = @provider.query
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
                # Else just mark all of the properties absent.
                self.class.validproperties.each { |name|
                    self.is = [name, :absent]
                }
            end
        end

        # Set all of the params' "is" value.  Most are parameters, but some
        # are properties.
        def setparams(hash)
            # Everything on packages is a parameter except :ensure
            hash.each { |param, value|
                if self.class.attrtype(param) == :property
                    self.is = [param, value]
                else
                    self[param] = value
                end
            }
        end
    end # Puppet.type(:package)
end

# $Id$
