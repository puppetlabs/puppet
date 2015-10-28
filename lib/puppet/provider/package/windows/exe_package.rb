require 'puppet/provider/package/windows/package'

class Puppet::Provider::Package::Windows
  class ExePackage < Puppet::Provider::Package::Windows::Package
    attr_reader :uninstall_string

    # Return an instance of the package from the registry, or nil
    def self.from_registry(name, values)
      if valid?(name, values)
        ExePackage.new(
          get_display_name(values),
          values['DisplayVersion'],
          values['UninstallString']
        )
      end
    end

    # Is this a valid executable package we should manage?
    def self.valid?(name, values)
      # See http://community.spiceworks.com/how_to/show/2238
      displayName = get_display_name(values)
      !!(displayName && displayName.length > 0 &&
         values['UninstallString'] &&
         values['UninstallString'].length > 0 &&
         values['WindowsInstaller'] != 1 && # DWORD
         name !~ /^KB[0-9]{6}/ &&
         values['ParentKeyName'] == nil &&
         values['Security Update'] == nil &&
         values['Update Rollup'] == nil &&
         values['Hotfix'] == nil)
    end

    def initialize(name, version, uninstall_string)
      super(name, version)

      @uninstall_string = uninstall_string
    end

    # Does this package match the resource?
    def match?(resource)
      resource[:name] == name
    end

    def self.install_command(resource)
      ['cmd.exe', '/c', 'start', '"puppet-install"', '/w', munge(resource[:source])]
    end

    def uninstall_command
      # 1. Launch using cmd /c start because if the executable is a console
      #    application Windows will automatically display its console window
      # 2. Specify a quoted title, otherwise if uninstall_string is quoted,
      #    start will interpret that to be the title, and get confused
      # 3. Specify /w (wait) to wait for uninstall to finish
      command = ['cmd.exe', '/c', 'start', '"puppet-uninstall"', '/w']

      # Only quote bare uninstall strings, e.g.
      #   C:\Program Files (x86)\Notepad++\uninstall.exe
      # Don't quote uninstall strings that are already quoted, e.g.
      #   "c:\ruby187\unins000.exe"
      # Don't quote uninstall strings that contain arguments:
      #   "C:\Program Files (x86)\Git\unins000.exe" /SILENT
      if uninstall_string =~ /\A[^"]*.exe\Z/i
        command << "\"#{uninstall_string}\""
      else
        command << uninstall_string
      end

      command
    end
  end
end
