module Puppet
  module Acceptance
    module WindowsUtils
      # Sets up a mock installer on the host.

      def create_mock_package(host, tmpdir, config = {}, installer_file = 'MockInstaller.cs', uninstaller_file = 'MockUninstaller.cs')
        installer_exe_path = "#{tmpdir}/#{config[:name].gsub(/\s+/, '')}Installer.exe".gsub('/', '\\')
        uninstaller_exe_path = "#{tmpdir}/#{config[:name].gsub(/\s+/, '')}Uninstaller.exe".gsub('/', '\\')
        tranformations = {
          package_display_name: config[:name],
          uninstaller_location: uninstaller_exe_path,
          install_commands:     config[:install_commands],
          uninstall_commands:   config[:uninstall_commands]
        }

        [
          { source: installer_file, destination: installer_exe_path },
          { source: uninstaller_file, destination: uninstaller_exe_path },
        ].each do |exe|
          fixture_path = File.join(
            File.dirname(__FILE__),
            '..',
            '..',
            '..',
            '..',
            'fixtures',
            exe[:source]
          )
          code = File.read(fixture_path) % tranformations
          build_mock_exe(host, exe[:destination], code)
        end
        # If the registry key still exists from a previous package install, then delete it.
        teardown do
          if package_installed?(host, config[:name])
            on host, powershell("\"Remove-Item HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\#{config[:name]}\"")
          end
        end
        # return the installer path for tests to use as the source: attribute
        installer_exe_path
      end

      def build_mock_exe(host, destination, code)
        # Make a source file containing the code on the SUT, the source file
        # will be the same location/name as the destination exe but with the .cs
        # extension
        source_path_on_host = destination.gsub(/\.exe$/, '.cs')
        create_remote_file(host, source_path_on_host.gsub('\\', '/'), code)
        # Create the installer.exe file by compiling the copied over C# code
        # with PowerShell
        create_installer_exe = "\"Add-Type"\
          " -TypeDefinition (Get-Content #{source_path_on_host} | Out-String)"\
          " -Language CSharp"\
          " -OutputAssembly #{destination}"\
          " -OutputType ConsoleApplication\""
        on host, powershell(create_installer_exe)
      end

      def package_installed?(host, name)
        # A successfully installed mock package will have created a registry key under
        # HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall. Simply checking
        # for that key should suffice as an indicator that the installer completed
        test_key = "\"Test-Path HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\#{name}\""
        on(host, powershell(test_key)) do |result|
          return result.stdout.chomp == 'True'
        end
      end
    end
  end
end
