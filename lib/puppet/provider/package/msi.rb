require 'puppet/provider/package'
require 'puppet/util/windows'

Puppet::Type.type(:package).provide(:msi, :parent => Puppet::Provider::Package) do
  desc "Windows package management by installing and removing MSIs.

    The `msi` provider is deprecated. Use the `windows` provider instead."

  confine    :operatingsystem => :windows

  has_feature :installable
  has_feature :uninstallable
  has_feature :install_options
  has_feature :uninstall_options

  class MsiPackage
    extend Enumerable
    include Puppet::Util::Windows::Registry
    extend Puppet::Util::Windows::Registry

    def self.installer
      WIN32OLE.new("WindowsInstaller.Installer")
    end

    def self.each(&block)
      inst = installer
      inst.UILevel = 2

      inst.Products.each do |guid|
        # products may be advertised, installed in a different user
        # context, etc, we only want to know about products currently
        # installed in our context.
        next unless inst.ProductState(guid) == 5

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

  def self.instances
    []
  end

  def initialize(resource = nil)
    Puppet.deprecation_warning "The `:msi` package provider is deprecated, use the `:windows` provider instead."
    super(resource)
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
    output = execute(command, :failonfail => false, :combine => true)

    check_result(output.exitstatus)
  end

  def uninstall
    fail("The productcode property is missing.") unless properties[:productcode]

    command = ['msiexec.exe', '/qn', '/norestart', '/x', properties[:productcode], uninstall_options].flatten.compact.join(' ')
    output = execute(command, :failonfail => false, :combine => true)

    check_result(output.exitstatus)
  end

  # (Un)install may "fail" because the package requested a reboot, the system requested a
  # reboot, or something else entirely. Reboot requests mean the package was installed
  # successfully, but we warn since we don't have a good reboot strategy.
  def check_result(hr)
    operation = resource[:ensure] == :absent ? 'uninstall' : 'install'

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa368542(v=vs.85).aspx
    case hr
    when 0
      # yeah
    when 1641
      warning("The package #{operation}ed successfully and the system is rebooting now.")
    when 3010
      warning("The package #{operation}ed successfully, but the system must be rebooted.")
    else
      raise Puppet::Util::Windows::Error.new("Failed to #{operation}", hr)
    end
  end

  def validate_source(value)
    fail("The source parameter cannot be empty when using the MSI provider.") if value.empty?
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options])
  end

  def shell_quote(value)
    value.include?(' ') ? %Q["#{value.gsub(/"/, '\"')}"] : value
  end
end
