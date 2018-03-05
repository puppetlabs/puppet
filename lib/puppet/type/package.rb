# Define the different packaging systems.  Each package system is implemented
# in a module, which then gets used to individually extend each package object.
# This allows packages to exist on the same machine using different packaging
# systems.

require 'puppet/parameter/package_options'
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:package) do
    @doc = "Manage packages.  There is a basic dichotomy in package
      support right now:  Some package types (such as yum and apt) can
      retrieve their own package files, while others (such as rpm and sun)
      cannot.  For those package formats that cannot retrieve their own files,
      you can use the `source` parameter to point to the correct file.

      Puppet will automatically guess the packaging format that you are
      using based on the platform you are on, but you can override it
      using the `provider` parameter; each provider defines what it
      requires in order to function, and you must meet those requirements
      to use a given provider.

      You can declare multiple package resources with the same `name`, as long
      as they specify different providers and have unique titles.

      Note that you must use the _title_ to make a reference to a package
      resource; `Package[<NAME>]` is not a synonym for `Package[<TITLE>]` like
      it is for many other resource types.

      **Autorequires:** If Puppet is managing the files specified as a
      package's `adminfile`, `responsefile`, or `source`, the package
      resource will autorequire those files."

    feature :reinstallable, "The provider can reinstall packages.",
      :methods => [:reinstall]
    feature :installable, "The provider can install packages.",
      :methods => [:install]
    feature :uninstallable, "The provider can uninstall packages.",
      :methods => [:uninstall]
    feature :upgradeable, "The provider can upgrade to the latest version of a
        package.  This feature is used by specifying `latest` as the
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
    feature :holdable, "The provider is capable of placing packages on hold
        such that they are not automatically upgraded as a result of
        other package dependencies unless explicit action is taken by
        a user or another package. Held is considered a superset of
        installed.",
      :methods => [:hold]
    feature :install_options, "The provider accepts options to be
      passed to the installer command."
    feature :uninstall_options, "The provider accepts options to be
      passed to the uninstaller command."
    feature :package_settings, "The provider accepts package_settings to be
      ensured for the given package. The meaning and format of these settings is
      provider-specific.",
      :methods => [:package_settings_insync?, :package_settings, :package_settings=]
    feature :virtual_packages, "The provider accepts virtual package names for install and uninstall."

    ensurable do
      desc <<-EOT
        What state the package should be in. On packaging systems that can
        retrieve new packages on their own, you can choose which package to
        retrieve by specifying a version number or `latest` as the ensure
        value. On packaging systems that manage configuration files separately
        from "normal" system files, you can uninstall config files by
        specifying `purged` as the ensure value. This defaults to `installed`.

        Version numbers must match the full version to install, including
        release if the provider uses a release moniker. Ranges or semver
        patterns are not accepted except for the `gem` package provider. For
        example, to install the bash package from the rpm
        `bash-4.1.2-29.el6.x86_64.rpm`, use the string `'4.1.2-29.el6'`.
      EOT

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

      newvalue(:held, :event => :package_held, :required_features => :holdable) do
        provider.hold
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
          self.fail Puppet::Error, _("Could not update: %{detail}") % { detail: detail }, detail
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
          self.fail Puppet::Error, _("Could not update: %{detail}") % { detail: detail }, detail
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
        @lateststamp ||= (Time.now.to_i - 1000)
        # Iterate across all of the should values, and see how they
        # turn out.

        @should.each { |should|
          case should
          when :present
            return true unless [:absent, :purged, :held].include?(is)
          when :latest
            # Short-circuit packages that are not present
            return false if is == :absent || is == :purged

            # Don't run 'latest' more than about every 5 minutes
            if @latest and ((Time.now.to_i - @lateststamp) / 60) < 5
              #self.debug "Skipping latest check"
            else
              begin
                @latest = provider.latest
                @lateststamp = Time.now.to_i
              rescue => detail
                error = Puppet::Error.new(_("Could not get latest version: %{detail}") % { detail: detail })
                error.set_backtrace(detail.backtrace)
                raise error
              end
            end

            case
              when is.is_a?(Array) && is.include?(@latest)
                return true
              when is == @latest
                return true
              when is == :present
                # This will only happen on retarded packaging systems
                # that can't query versions.
                return true
              else
                self.debug "#{@resource.name} #{is.inspect} is installed, latest is #{@latest.inspect}"
            end


          when :absent
            return true if is == :absent || is == :purged
          when :purged
            return true if is == :purged
          # this handles version number matches and
          # supports providers that can have multiple versions installed
          when *Array(is)
            return true
          else
            # We have version numbers, and no match. If the provider has
            # additional logic, run it here.
            return provider.insync?(is) if provider.respond_to?(:insync?)
          end
        }

        false
      end

      # This retrieves the current state. LAK: I think this method is unused.
      def retrieve
        provider.properties[:ensure]
      end

      # Provide a bit more information when logging upgrades.
      def should_to_s(newvalue = @should)
        if @latest
          super(@latest)
        else
          super(newvalue)
        end
      end

      def change_to_s(currentvalue, newvalue)
        # Handle transitioning from any previous state to 'purged'
        return 'purged' if newvalue == :purged

        # Check for transitions from nil/purged/absent to 'created' (any state that is not absent and not purged)
        return 'created' if (currentvalue.nil? || currentvalue == :absent || currentvalue == :purged) && (newvalue != :absent && newvalue != :purged)

        # The base should handle the normal property transitions
        super(currentvalue, newvalue)
      end
    end

    newparam(:name) do
      desc "The package name.  This is the name that the packaging
      system uses internally, which is sometimes (especially on Solaris)
      a name that is basically useless to humans.  If a package goes by
      several names, you can use a single title and then set the name
      conditionally:

          # In the 'openssl' class
          $ssl = $operatingsystem ? {
            solaris => SMCossl,
            default => openssl
          }

          package { 'openssl':
            ensure => installed,
            name   => $ssl,
          }

          ...

          $ssh = $operatingsystem ? {
            solaris => SMCossh,
            default => openssh
          }

          package { 'openssh':
            ensure  => installed,
            name    => $ssh,
            require => Package['openssl'],
          }

      "
      isnamevar

      validate do |value|
        if !value.is_a?(String)
          raise ArgumentError, _("Name must be a String not %{klass}") % { klass: value.class }
        end
      end
    end

    # We call providify here so that we can set provider as a namevar.
    # Normally this method is called after newtype finishes constructing this
    # Type class.
    providify
    paramclass(:provider).isnamevar

    # We have more than one namevar, so we need title_patterns. However, we
    # cheat and set the patterns to map to name only and completely ignore
    # provider. So far, the logic that determines uniqueness appears to just
    # "Do The Right Thing™" when the provider is explicitly set by the user.
    #
    # The following resources will be seen as unique by puppet:
    #
    #     # Uniqueness Key: ['mysql', nil]
    #     package{'mysql': }
    #
    #     # Uniqueness Key: ['mysql', 'gem']
    #     package{'gem-mysql':
    #       name     => 'mysql,
    #       provider => gem
    #     }
    #
    # This does not handle the case where providers like 'yum' and 'rpm' should
    # clash. Also, declarations that implicitly use the default provider will
    # clash with those that explicitly use the default.
    def self.title_patterns
      # This is the default title pattern for all types, except hard-wired to
      # set only name.
      [ [ /(.*)/m, [ [:name] ] ] ]
    end

    newproperty(:package_settings, :required_features=>:package_settings) do
      desc "Settings that can change the contents or configuration of a package.

        The formatting and effects of package_settings are provider-specific; any
        provider that implements them must explain how to use them in its
        documentation. (Our general expectation is that if a package is
        installed but its settings are out of sync, the provider should
        re-install that package with the desired settings.)

        An example of how package_settings could be used is FreeBSD's port build
        options --- a future version of the provider could accept a hash of options,
        and would reinstall the port if the installed version lacked the correct
        settings.

            package { 'www/apache22':
              package_settings => { 'SUEXEC' => false }
            }

        Again, check the documentation of your platform's package provider to see
        the actual usage."

      validate do |value|
        if provider.respond_to?(:package_settings_validate)
          provider.package_settings_validate(value)
        else
          super(value)
        end
      end

      munge do |value|
        if provider.respond_to?(:package_settings_munge)
          provider.package_settings_munge(value)
        else
          super(value)
        end
      end

      def insync?(is)
        provider.package_settings_insync?(should, is)
      end

      def should_to_s(newvalue)
        if provider.respond_to?(:package_settings_should_to_s)
          provider.package_settings_should_to_s(should, newvalue)
        else
          super(newvalue)
        end
      end

      def is_to_s(currentvalue)
        if provider.respond_to?(:package_settings_is_to_s)
          provider.package_settings_is_to_s(should, currentvalue)
        else
          super(currentvalue)
        end
      end

      def change_to_s(currentvalue, newvalue)
        if provider.respond_to?(:package_settings_change_to_s)
          provider.package_settings_change_to_s(currentvalue, newvalue)
        else
          super(currentvalue,newvalue)
        end
      end
    end

    newparam(:source) do
      desc "Where to find the package file. This is only used by providers that don't
        automatically download packages from a central repository. (For example:
        the `yum` and `apt` providers ignore this attribute, but the `rpm` and
        `dpkg` providers require it.)

        Different providers accept different values for `source`. Most providers
        accept paths to local files stored on the target system. Some providers
        may also accept URLs or network drive paths. Puppet will not
        automatically retrieve source files for you, and usually just passes the
        value of `source` to the package installation command.

        You can use a `file` resource if you need to manually copy package files
        to the target system."

      validate do |value|
        provider.validate_source(value)
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

        This attribute is only used on Solaris. Its value should be a path to a
        local file stored on the target system. Solaris's package tools expect
        either an absolute file path or a relative path to a file in
        `/var/sadm/install/admin`.

        The value of `adminfile` will be passed directly to the `pkgadd` or
        `pkgrm` command with the `-a <ADMINFILE>` option."
    end

    newparam(:responsefile) do
      desc "A file containing any necessary answers to questions asked by
        the package.  This is currently used on Solaris and Debian.  The
        value will be validated according to system rules, but it should
        generally be a fully qualified path."
    end

    newparam(:configfiles) do
      desc "Whether to keep or replace modified config files when installing or
        upgrading a package. This only affects the `apt` and `dpkg` providers.
        Defaults to `keep`."

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

    newparam(:flavor) do
      desc "OpenBSD supports 'flavors', which are further specifications for
        which type of package you want."
    end

    newparam(:install_options, :parent => Puppet::Parameter::PackageOptions, :required_features => :install_options) do
      desc <<-EOT
        An array of additional options to pass when installing a package. These
        options are package-specific, and should be documented by the software
        vendor.  One commonly implemented option is `INSTALLDIR`:

            package { 'mysql':
              ensure          => installed,
              source          => 'N:/packages/mysql-5.5.16-winx64.msi',
              install_options => [ '/S', { 'INSTALLDIR' => 'C:\\mysql-5.5' } ],
            }

        Each option in the array can either be a string or a hash, where each
        key and value pair are interpreted in a provider specific way.  Each
        option will automatically be quoted when passed to the install command.

        With Windows packages, note that file paths in an install option must
        use backslashes. (Since install options are passed directly to the
        installation command, forward slashes won't be automatically converted
        like they are in `file` resources.) Note also that backslashes in
        double-quoted strings _must_ be escaped and backslashes in single-quoted
        strings _can_ be escaped.
      EOT
    end

    newparam(:uninstall_options, :parent => Puppet::Parameter::PackageOptions, :required_features => :uninstall_options) do
      desc <<-EOT
        An array of additional options to pass when uninstalling a package. These
        options are package-specific, and should be documented by the software
        vendor.  For example:

            package { 'VMware Tools':
              ensure            => absent,
              uninstall_options => [ { 'REMOVE' => 'Sync,VSS' } ],
            }

        Each option in the array can either be a string or a hash, where each
        key and value pair are interpreted in a provider specific way.  Each
        option will automatically be quoted when passed to the uninstall
        command.

        On Windows, this is the **only** place in Puppet where backslash
        separators should be used.  Note that backslashes in double-quoted
        strings _must_ be double-escaped and backslashes in single-quoted
        strings _may_ be double-escaped.
      EOT
    end

    newparam(:allow_virtual, :boolean => true, :parent => Puppet::Parameter::Boolean, :required_features => :virtual_packages) do
      desc 'Specifies if virtual package names are allowed for install and uninstall.'

      defaultto true
    end

    autorequire(:file) do
      autos = []
      [:responsefile, :adminfile].each { |param|
        if val = self[param]
          autos << val
        end
      }

      if source = self[:source] and absolute_path?(source)
        autos << source
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

    def present?(current_values)
      super && current_values[:ensure] != :purged
    end

    # This parameter exists to ensure backwards compatibility is preserved.
    # See https://github.com/puppetlabs/puppet/pull/2614 for discussion.
    # If/when a metaparameter for controlling how arbitrary resources respond
    # to refreshing is created, that will supersede this, and this will be
    # deprecated.
    newparam(:reinstall_on_refresh) do
      desc "Whether this resource should respond to refresh events (via `subscribe`,
        `notify`, or the `~>` arrow) by reinstalling the package. Only works for
        providers that support the `reinstallable` feature.

        This is useful for source-based distributions, where you may want to
        recompile a package if the build options change.

        If you use this, be careful of notifying classes when you want to restart
        services. If the class also contains a refreshable package, doing so could
        cause unnecessary re-installs.

        Defaults to `false`."
      newvalues(:true, :false)

      defaultto :false
    end

    # When a refresh event is triggered, calls reinstall on providers
    # that support the reinstall_on_refresh parameter.
    def refresh
      if provider.reinstallable? &&
        @parameters[:reinstall_on_refresh].value == :true &&
        @parameters[:ensure].value != :purged &&
        @parameters[:ensure].value != :absent &&
        @parameters[:ensure].value != :held

        provider.reinstall
      end
    end
  end
end
