require 'puppet/provider/package'
require 'puppet/util/windows'
require 'puppet/provider/package/windows/package'

Puppet::Type.type(:package).provide(:windows, :parent => Puppet::Provider::Package) do
  desc "Windows package management.

    This provider supports either MSI or self-extracting executable installers.

    This provider requires a `source` attribute when installing the package.
    It accepts paths to local files, mapped drives, or UNC paths.

    This provider supports the `install_options` and `uninstall_options`
    attributes, which allow command-line flags to be passed to the installer.
    These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
    or an array where each element is either a string or a hash.

    If the executable requires special arguments to perform a silent install or
    uninstall, then the appropriate arguments should be specified using the
    `install_options` or `uninstall_options` attributes, respectively.  Puppet
    will automatically quote any option that contains spaces."

  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  has_feature :installable
  has_feature :uninstallable
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :versionable

  attr_accessor :package

  # Return an array of provider instances
  def self.instances
    Puppet::Provider::Package::Windows::Package.map do |pkg|
      provider = new(to_hash(pkg))
      provider.package = pkg
      provider
    end
  end

  def self.to_hash(pkg)
    {
      :name     => pkg.name,
      :ensure   => pkg.version || :installed,
      :provider => :windows
    }
  end

  # Query for the provider hash for the current resource. The provider we
  # are querying, may not have existed during prefetch
  def query
    Puppet::Provider::Package::Windows::Package.find do |pkg|
      if pkg.match?(resource)
        return self.class.to_hash(pkg)
      end
    end
    nil
  end

  def install
    installer = Puppet::Provider::Package::Windows::Package.installer_class(resource)

    command = [installer.install_command(resource), install_options].flatten.compact.join(' ')
    output = execute(command, :failonfail => false, :combine => true)

    check_result(output.exitstatus)
  end

  def uninstall
    command = [package.uninstall_command, uninstall_options].flatten.compact.join(' ')
    output = execute(command, :failonfail => false, :combine => true)

    check_result(output.exitstatus)
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa368542(v=vs.85).aspx
  self::ERROR_SUCCESS                  = 0
  self::ERROR_SUCCESS_REBOOT_INITIATED = 1641
  self::ERROR_SUCCESS_REBOOT_REQUIRED  = 3010

  # (Un)install may "fail" because the package requested a reboot, the system requested a
  # reboot, or something else entirely. Reboot requests mean the package was installed
  # successfully, but we warn since we don't have a good reboot strategy.
  def check_result(hr)
    operation = resource[:ensure] == :absent ? 'uninstall' : 'install'

    case hr
    when self.class::ERROR_SUCCESS
      # yeah
    when self.class::ERROR_SUCCESS_REBOOT_INITIATED
      warning("The package #{operation}ed successfully and the system is rebooting now.")
    when self.class::ERROR_SUCCESS_REBOOT_REQUIRED
      warning("The package #{operation}ed successfully, but the system must be rebooted.")
    else
      raise Puppet::Util::Windows::Error.new("Failed to #{operation}", hr)
    end
  end

  # This only gets called if there is a value to validate, but not if it's absent
  def validate_source(value)
    fail("The source parameter cannot be empty when using the Windows provider.") if value.empty?
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options])
  end
end
