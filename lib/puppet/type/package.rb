# Define the different packaging systems.  Each package system is implemented
# in a module, which then gets used to individually extend each package object.
# This allows packages to exist on the same machine using different packaging
# systems.

module Puppet
    newtype(:package) do
        @doc = "Manage packages.  There is a basic dichotomy in package
            support right now:  Some package types (e.g., yum and apt) can
            retrieve their own package files, while others (e.g., rpm and
            sun) cannot.  For those package formats that cannot retrieve
            their own files, you can use the ``source`` parameter to point to
            the correct file.

            Puppet will automatically guess the packaging format that you are
            using based on the platform you are on, but you can override it
            using the ``provider`` parameter; each provider defines what it
            requires in order to function, and you must meet those requirements
            to use a given provider."

        feature :installable, "The provider can install packages.",
            :methods => [:install]
        feature :uninstallable, "The provider can uninstall packages.",
            :methods => [:uninstall]
        feature :upgradeable, "The provider can upgrade to the latest version of a
                package.  This feature is used by specifying ``latest`` as the
                desired value for the package.",
            :methods => [:update, :latest]
        feature :purgeable, "The provider can purge packages.  This generally means
                that all traces of the package are removed, including
                existing configuration files.  This feature is thus destructive
                and should be used with the utmost care.",
            :methods => [:purge]
        feature :versionable, "The provider is capable of interrogating the
                package database for installed version(s), and can select
                which out of a set of available versions of a package to
                install if asked."

        ensurable do
            desc "What state the package should be in.
                *latest* only makes sense for those packaging formats that can
                retrieve new packages on their own and will throw an error on
                those that cannot.  For those packaging systems that allow you
                to specify package versions, specify them here.  Similarly,
                *purged* is only useful for packaging systems that support
                the notion of managing configuration files separately from
                'normal' system files."

            attr_accessor :latest

            newvalue(:present, :event => :package_installed) do
                provider.install
            end

            newvalue(:absent, :event => :package_removed) do
                provider.uninstall
            end

            newvalue(:purged, :event => :package_purged, :required_features => :purgeable) do
                provider.purge
            end

            # Alias the 'present' value.
            aliasvalue(:installed, :present)

            newvalue(:latest, :required_features => :upgradeable) do
                # Because yum always exits with a 0 exit code, there's a retrieve
                # in the "install" method.  So, check the current state now,
                # to compare against later.
                current = self.retrieve
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

            newvalue(/./, :required_features => :versionable) do
                begin
                    provider.install
                rescue => detail
                    self.fail "Could not update: %s" % detail
                end

                if self.retrieve == :absent
                    :package_installed
                else
                    :package_changed
                end
            end


            defaultto :installed

            # Override the parent method, because we've got all kinds of
            # funky definitions of 'in sync'.
            def insync?(is)
                @should ||= []

                @latest = nil unless defined? @latest
                @lateststamp ||= (Time.now.to_i - 1000)
                # Iterate across all of the should values, and see how they
                # turn out.

                @should.each { |should|
                    case should
                    when :present
                        return true unless [:absent, :purged].include?(is)
                    when :latest
                        # Short-circuit packages that are not present
                        return false if is == :absent or is == :purged

                        # Don't run 'latest' more than about every 5 minutes
                        if @latest and ((Time.now.to_i - @lateststamp) / 60) < 5
                            #self.debug "Skipping latest check"
                        else
                            begin
                                @latest = provider.latest
                                @lateststamp = Time.now.to_i
                            rescue => detail
                                error = Puppet::Error.new("Could not get latest version: %s" % detail.to_s)
                                error.set_backtrace(detail.backtrace)
                                raise error
                            end
                        end

                        case is
                        when @latest
                            return true
                        when :present
                            # This will only happen on retarded packaging systems
                            # that can't query versions.
                            return true
                        else
                            self.debug "%s %s is installed, latest is %s" %
                                [@resource.name, is.inspect, @latest.inspect]
                        end
                    when :absent
                        return true if is == :absent or is == :purged
                    when :purged
                        return true if is == :purged
                    when is
                        return true
                    end
                }

                return false
            end

            # This retrieves the current state. LAK: I think this method is unused.
            def retrieve
                return provider.properties[:ensure]
            end

            # Provide a bit more information when logging upgrades.
            def should_to_s(newvalue = @should)
                if @latest
                    @latest.to_s
                else
                    super(newvalue)
                end
            end
        end

        newparam(:name) do
            desc "The package name.  This is the name that the packaging
            system uses internally, which is sometimes (especially on Solaris)
            a name that is basically useless to humans.  If you want to
            abstract package installation, then you can use aliases to provide
            a common name to packages::

                # In the 'openssl' class
                $ssl = $operatingsystem ? {
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

                $ssh = $operatingsystem ? {
                    solaris => SMCossh,
                    default => openssh
                }

                # Use the alias to specify a dependency, rather than
                # having another selector to figure it out again.
                package { $ssh:
                    ensure => installed,
                    alias => openssh,
                    require => Package[openssl]
                }

            "
            isnamevar
        end

        newparam(:source) do
            desc "Where to find the actual package.  This must be a local file
                (or on a network file system) or a URL that your specific
                packaging type understands; Puppet will not retrieve files for you."
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
                @resource[:provider] = value

                @resource[:provider]
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
                the package.  This is currently used on Solaris and Debian.  The
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

        # This only exists for testing.
        def clear
            if obj = @parameters[:ensure]
                obj.latest = nil
            end
        end

        # The 'query' method returns a hash of info if the package
        # exists and returns nil if it does not.
        def exists?
            @provider.get(:ensure) != :absent
        end

        def retrieve
            @provider.properties.inject({}) do |props, ary|
                name, value = ary
                if prop = @parameters[name]
                    props[prop] = value
                end
                props
            end
        end
    end # Puppet::Type.type(:package)
end

