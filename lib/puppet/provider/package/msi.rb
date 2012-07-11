require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:msi, :parent => Puppet::Provider::Package) do
  desc "Windows package management by installing and removing MSIs.

    This provider requires a `source` attribute, and will accept paths to local
    files, mapped drives, or UNC paths."

  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  has_feature :installable
  has_feature :uninstallable
  has_feature :install_options

  class MsiPackage
    extend Enumerable

    # From msi.h
    INSTALLSTATE_DEFAULT = 5 # product is installed for the current user
    INSTALLUILEVEL_NONE  = 2 # completely silent installation

    def self.installer
      require 'win32ole'
      WIN32OLE.new("WindowsInstaller.Installer")
    end

    def self.each(&block)
      inst = installer
      inst.UILevel = INSTALLUILEVEL_NONE

      inst.Products.each do |guid|
        # products may be advertised, installed in a different user
        # context, etc, we only want to know about products currently
        # installed in our context.
        next unless inst.ProductState(guid) == INSTALLSTATE_DEFAULT

        package = {
          :name        => inst.ProductInfo(guid, 'ProductName'),
          # although packages have a version, the provider isn't versionable,
          # so we can't return a version
          # :ensure      => inst.ProductInfo(guid, 'VersionString'),
          :ensure      => :installed,
          :provider    => :msi,
          :productcode => guid,
          :packagecode => inst.ProductInfo(guid, 'PackageCode')
        }

        yield package
      end
    end
  end

  # Get an array of provider instances for currently installed packages
  def self.instances
    MsiPackage.enum_for.map { |package| new(package) }
  end

  # Find first package whose PackageCode, e.g. {B2BE95D2-CD2C-46D6-8D27-35D150E58EC9},
  # matches the resource name (case-insensitively due to hex) or the ProductName matches
  # the resource name. The ProductName is not guaranteed to be unique, but the PackageCode
  # should be if the package is authored correctly.
  def query
    MsiPackage.enum_for.find do |package|
      resource[:name].casecmp(package[:packagecode]) == 0 || resource[:name] == package[:name]
    end
  end

  def install
    fail("The source parameter is required when using the MSI provider.") unless resource[:source]

    # Unfortunately, we can't use the msiexec method defined earlier,
    # because of the special quoting we need to do around the MSI
    # properties to use.
    command = ['msiexec.exe', '/qn', '/norestart', '/i', shell_quote(resource[:source]), install_options].flatten.compact.join(' ')
    execute(command, :combine => true)

    check_result(exit_status)
  end

  def uninstall
    fail("The productcode property is missing.") unless properties[:productcode]

    command = ['msiexec.exe', '/qn', '/norestart', '/x', properties[:productcode]].flatten.compact.join(' ')
    execute(command, :combine => true)

    check_result(exit_status)
  end

  def exit_status
    $CHILD_STATUS.exitstatus
  end

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa368542(v=vs.85).aspx
  ERROR_SUCCESS                  = 0
  ERROR_SUCCESS_REBOOT_INITIATED = 1641
  ERROR_SUCCESS_REBOOT_REQUIRED  = 3010

  # (Un)install may "fail" because the package requested a reboot, the system requested a
  # reboot, or something else entirely. Reboot requests mean the package was installed
  # successfully, but we warn since we don't have a good reboot strategy.
  def check_result(hr)
    operation = resource[:ensure] == :absent ? 'uninstall' : 'install'

    case hr
    when ERROR_SUCCESS
      # yeah
    when 194
      warning("The package requested a reboot to finish the operation.")
    when ERROR_SUCCESS_REBOOT_INITIATED
      warning("The package #{operation}ed successfully and the system is rebooting now.")
    when ERROR_SUCCESS_REBOOT_REQUIRED
      warning("The package #{operation}ed successfully, but the system must be rebooted.")
    else
      raise Puppet::Util::Windows::Error.new("Failed to #{operation}", hr)
    end
  end

  def validate_source(value)
    fail("The source parameter cannot be empty when using the MSI provider.") if value.empty?
  end

  def install_options
    # properties is a string delimited by spaces, so each key value must be quoted
    properties_for_command = nil
    if resource[:install_options]
      properties_for_command = resource[:install_options].collect do |k,v|
        property = shell_quote k
        value    = shell_quote v

        "#{property}=#{value}"
      end
    end

    properties_for_command
  end

  def shell_quote(value)
    value.include?(' ') ? %Q["#{value.gsub(/"/, '\"')}"] : value
  end
end
