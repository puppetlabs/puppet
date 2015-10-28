require 'puppet/provider/package/windows/package'

class Puppet::Provider::Package::Windows
  class MsiPackage < Puppet::Provider::Package::Windows::Package
    attr_reader :productcode, :packagecode

    # From msi.h
    INSTALLSTATE_DEFAULT = 5 # product is installed for the current user
    INSTALLUILEVEL_NONE  = 2 # completely silent installation

    # Get the COM installer object, it's in a separate method for testing
    def self.installer
      # REMIND: when does the COM release happen?
      WIN32OLE.new("WindowsInstaller.Installer")
    end

    # Return an instance of the package from the registry, or nil
    def self.from_registry(name, values)
      if valid?(name, values)
        inst = installer

        if inst.ProductState(name) == INSTALLSTATE_DEFAULT
          MsiPackage.new(get_display_name(values),
                         values['DisplayVersion'],
                         name, # productcode
                         inst.ProductInfo(name, 'PackageCode'))
        end
      end
    end

    # Is this a valid MSI package we should manage?
    def self.valid?(name, values)
      # See http://community.spiceworks.com/how_to/show/2238
      displayName = get_display_name(values)
      !!(displayName && displayName.length > 0 &&
         values['WindowsInstaller'] == 1 && # DWORD
         name =~ /\A\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}\Z/i)
    end

    def initialize(name, version, productcode, packagecode)
      super(name, version)

      @productcode = productcode
      @packagecode = packagecode
    end

    # Does this package match the resource?
    def match?(resource)
      resource[:name].casecmp(packagecode) == 0 ||
        resource[:name].casecmp(productcode) == 0 ||
        resource[:name] == name
    end

    def self.install_command(resource)
      ['msiexec.exe', '/qn', '/norestart', '/i', munge(resource[:source])]
    end

    def uninstall_command
      ['msiexec.exe', '/qn', '/norestart', '/x', productcode]
    end
  end
end
