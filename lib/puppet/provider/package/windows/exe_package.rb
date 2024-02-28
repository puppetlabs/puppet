# frozen_string_literal: true

require_relative '../../../../puppet/provider/package/windows/package'

class Puppet::Provider::Package::Windows
  class ExePackage < Puppet::Provider::Package::Windows::Package
    attr_reader :uninstall_string

    # registry values to load under each product entry in
    # HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
    # for this provider
    REG_VALUE_NAMES = [
      'DisplayVersion',
      'UninstallString',
      'ParentKeyName',
      'Security Update',
      'Update Rollup',
      'Hotfix',
      'WindowsInstaller',
    ]

    def self.register(path)
      Puppet::Type::Package::ProviderWindows.paths ||= []
      Puppet::Type::Package::ProviderWindows.paths << path
    end

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
         values['ParentKeyName'].nil? &&
         values['Security Update'].nil? &&
         values['Update Rollup'].nil? &&
         values['Hotfix'].nil?)
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
      file_location = resource[:source]
      if file_location.start_with?('http://', 'https://')
        tempfile = Tempfile.new(['', '.exe'])
        begin
          uri = URI(Puppet::Util.uri_encode(file_location))
          client = Puppet.runtime[:http]
          client.get(uri, options: { include_system_store: true }) do |response|
            raise Puppet::HTTP::ResponseError.new(response) unless response.success?

            File.open(tempfile.path, 'wb') do |file|
              response.read_body do |data|
                file.write(data)
              end
            end
          end
        rescue => detail
          raise Puppet::Error.new(_("Error when installing %{package}: %{detail}") % { package: resource[:name], detail: detail.message }, detail)
        ensure
          self.register(tempfile.path)
          tempfile.close()
          file_location = tempfile.path
        end
      end

      munge(file_location)
    end

    def uninstall_command
      # Only quote bare uninstall strings, e.g.
      #   C:\Program Files (x86)\Notepad++\uninstall.exe
      # Don't quote uninstall strings that are already quoted, e.g.
      #   "c:\ruby187\unins000.exe"
      # Don't quote uninstall strings that contain arguments:
      #   "C:\Program Files (x86)\Git\unins000.exe" /SILENT
      if uninstall_string =~ /\A[^"]*.exe\Z/i
        command = "\"#{uninstall_string}\""
      else
        command = uninstall_string
      end

      command
    end
  end
end
