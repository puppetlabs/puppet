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

    def self.install_command(resource, install_options)
      Puppet::Util::Windows::PowershellCommandString.make_powershell_command(
        munge(resource[:source]),
        arguments: install_options
      )
    end

    def uninstall_command(uninstall_options)
      # split the uninstall_command on the first instance of
      # .exe by only allowing split to return an array of size
      # two, forcing the function to only return the split of
      # the first instance of the .exe string
      #
      # anything after .exe(") is assumed to be arguments to the
      # uninstaller
      arguments = uninstall_string.split(/\.exe"?/, 2)[1]
      # The uninstall command is the uninstall_string with the
      # arguments removed.
      command = uninstall_string.gsub(arguments, '')
      # Only quote bare uninstall strings, e.g.
      #   C:\Program Files (x86)\Notepad++\uninstall.exe
      # Don't quote uninstall strings that are already quoted, e.g.
      #   "c:\ruby187\unins000.exe"
      # Don't quote uninstall strings that contain arguments:
      #   "C:\Program Files (x86)\Git\unins000.exe" /SILENT
      if command =~ /\A[^"]*.exe\Z/i
        command = "\"#{command}\""
      end
      Puppet::Util::Windows::PowershellCommandString.make_powershell_command(
        command,
        arguments: [uninstall_options, arguments]
      )
    end
  end
end
