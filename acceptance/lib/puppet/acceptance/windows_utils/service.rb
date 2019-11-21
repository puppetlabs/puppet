module Puppet
  module Acceptance
    module WindowsUtils
      # Sets up a mock service on the host. The methodology here is a simplified
      # version of what's described in https://msdn.microsoft.com/en-us/magazine/mt703436.aspx
      def setup_service(host, config = {}, service_file = 'MockService.cs')
        config[:name] ||= "Mock Service"
        config[:display_name] ||= "#{config[:name]} (Puppet Acceptance Tests)"
        config[:description] ||= "Service created solely for acceptance testing the Puppet Windows Service provider"

        # Create a temporary directory to store the service's C# source code +
        # its .exe file.
        tmpdir = host.tmpdir("mock_service")

        # Copy-over the C# code
        code_fixture_path = File.join(
          File.dirname(__FILE__),
          '..',
          '..',
          '..',
          '..',
          'fixtures',
          service_file
        )
        code = File.read(code_fixture_path) % {
          service_name: config[:name],
          start_sleep: config[:start_sleep],
          pause_sleep: config[:pause_sleep],
          continue_sleep: config[:continue_sleep],
          stop_sleep: config[:stop_sleep]
        }
        code_path_unix = "#{tmpdir}/source.cs"
        code_path_win = code_path_unix.gsub('/', '\\')
        create_remote_file(host, code_path_unix, code)

        # Create the service.exe file by compiling the copied over C# code
        # with PowerShell
        service_exe_path_win = "#{tmpdir}/#{config[:name]}.exe".gsub('/', '\\')
        create_service_exe = "\"Add-Type"\
          " -TypeDefinition (Get-Content #{code_path_win} | Out-String)"\
          " -Language CSharp"\
          " -OutputAssembly #{service_exe_path_win}"\
          " -OutputType ConsoleApplication"\
          " -ReferencedAssemblies 'System.ServiceProcess'\""
        on host, powershell(create_service_exe)

        # Now register the service with SCM
        register_service_with_scm = "\"New-Service"\
          " #{config[:name]}"\
          " #{service_exe_path_win}"\
          " -DisplayName '#{config[:display_name]}'"\
          " -Description '#{config[:description]}'"\
          " -StartupType Automatic\""
        on host, powershell(register_service_with_scm)

        # Ensure that our service is deleted after the tests
        teardown { delete_service(host, config[:name]) }
      end

      def delete_service(host, name)
        # Check if our service has already been deleted. If so, then we
        # have nothing else to do.
        begin
          on host, powershell("Get-Service #{name}")
        rescue Beaker::Host::CommandFailure
          return
        end

        # Ensure that our service process is killed. We cannot do a Stop-Service here
        # b/c there's a chance that our service could be in a pending state (e.g.
        # "PausePending", "ContinuePending"). If this is the case, then Stop-Service
        # will fail.
        on host, powershell("\"Get-Process #{name} -ErrorAction SilentlyContinue | Stop-Process -Force\" | exit 0")

        # Now remove our service. We use sc.exe because older versions of PowerShell
        # may not have the Remove-Service commandlet.
        on agent, "sc.exe delete #{name}"
      end

      # Config should be a hash of <property> => <expected value>
      def assert_service_properties_on(host, name, properties = {})
        properties.each do |property, expected_value|
          # We need to get the underlying WMI object for the service since that
          # object contains all of our service properties. The one returned by
          # Get-Service only has these properties for newer versions of PowerShell.
          get_property_value = "\"Get-WmiObject -Class Win32_Service"\
            " | Where-Object { \\$_.name -eq '#{name}' }"\
            " | ForEach-Object { \\$_.#{property} }\""

          on(host, powershell(get_property_value)) do |result|
            actual_value = result.stdout.chomp

            property_str = "#{name}[#{property}]"
            assert_match(expected_value, actual_value, "EXPECTED: #{property_str} = #{expected_value}, ACTUAL: #{property_str} = #{actual_value}")
          end
        end
      end

      def assert_service_startmode_delayed(host, name)
        get_delayed_service = "\"Get-ChildItem HKLM:\\SYSTEM\\CurrentControlSet\\Services"\
          " | Where-Object { \\$_.Property -Contains 'DelayedAutoStart' -And \\$_.PsChildName -Like '#{name}' }"\
          " | Select-Object -ExpandProperty PSChildName\""

        on(host, powershell(get_delayed_service)) do |result|
          svc = result.stdout.chomp
          assert(!svc.empty?, "Service #{name} does not exist or is not a delayed service")
        end
      end
    end
  end
end
