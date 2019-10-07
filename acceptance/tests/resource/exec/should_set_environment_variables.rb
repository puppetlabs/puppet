test_name "The Exec resource should set user-specified environment variables" do
  tag 'audit:high',
      'audit:acceptance'

  # Would be nice to parse the actual values from puppet_output,
  # but that would require some complicated matching since
  # puppet_output contains other stuff.
  def assert_env_var_values(puppet_output, expected_values)
    expected_values.each do |env_var, value|
      assert_match(/#{env_var}=#{value}/, puppet_output, "Expected '#{env_var}=#{value}' to be printed as part of the output!")
    end
  end

  agents.each do |agent|
    # Calculate some top-level variables/functions we
    # will need for our tests.
    unless agent.platform =~ /windows/
      path = '/usr/bin:/usr/sbin:/bin:/sbin'
      print_env_vars = lambda do |*env_vars|
        env_vars_str = env_vars.map do |env_var|
          "#{env_var}=$#{env_var}"
        end.join(" ")

        "echo #{env_vars_str}"
      end
    else
      # Powershell's directory is dependent on what version of Powershell is
      # installed on the system (e.g. v1.0, v2.0), so we need to programmatically
      # calculate the executable's directory to add to our PATH variable.
      powershell_path = on(agent, "cmd.exe /c where powershell.exe").stdout.chomp
      *powershell_dir, _ = powershell_path.split('\\')
      powershell_dir = powershell_dir.join('\\')

      path = "C:\Windows\System32;#{powershell_dir}"
      print_env_vars = lambda do |*env_vars|
        env_vars_str = env_vars.map do |env_var|
          "#{env_var}=$env:#{env_var}"
        end

        "powershell.exe \"Write-Host -NoNewLine #{env_vars_str}\""
      end
    end

    # Easier to read than a def. The def. would require us
    # to specify the host as a param. in order to get the path
    # and print_cwd command, which is unnecessary clutter.
    exec_resource_manifest = lambda do |params = {}|
      default_params = {
        :logoutput => true,
        :path      => path
      }
      params = default_params.merge(params)

      params_str = params.map do |param, value|
        value_str = value.to_s
        # Single quote the strings in case our value is a Windows
        # path
        value_str = "'#{value_str}'" if value.is_a?(String)

        "  #{param} => #{value_str}"
      end.join(",\n")

      <<-MANIFEST
  exec { 'run_test_command':
    #{params_str}
  }
MANIFEST
    end

    step 'Passes the user-specified environment variables into the command' do
      manifest = exec_resource_manifest.call(
        command: print_env_vars.call('ENV_VAR_ONE', 'ENV_VAR_TWO'),
        environment: ['ENV_VAR_ONE=VALUE_ONE', 'ENV_VAR_TWO=VALUE_TWO']
      )

      apply_manifest_on(agent, manifest) do |result|
        assert_env_var_values(result.stdout, ENV_VAR_ONE: 'VALUE_ONE', ENV_VAR_TWO: 'VALUE_TWO')
      end
    end

    step "Temporarily overrides previously set environment variables" do
      manifest = exec_resource_manifest.call(
        command: print_env_vars.call('ENV_VAR_ONE'),
        environment: ['ENV_VAR_ONE=VALUE_OVERRIDE']
      )

      apply_manifest_on(agent, manifest, environment: { 'ENV_VAR_ONE' => 'VALUE' }) do |result|
        assert_env_var_values(result.stdout, ENV_VAR_ONE: 'VALUE_OVERRIDE')
      end
    end

    step "Temporarily overrides previously set environment variables even if the passed-in value is empty" do
      manifest = exec_resource_manifest.call(
        command: print_env_vars.call('ENV_VAR_ONE'),
        environment: ['ENV_VAR_ONE=']
      )

      apply_manifest_on(agent, manifest, environment: { 'ENV_VAR_ONE' => 'VALUE' }) do |result|
        assert_env_var_values(result.stdout, ENV_VAR_ONE: '')
      end
    end
  end
end
