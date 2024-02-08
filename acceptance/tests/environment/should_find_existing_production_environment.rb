test_name "should find existing production environment"
tag 'audit:high'

require 'puppet/acceptance/i18ndemo_utils'
extend Puppet::Acceptance::I18nDemoUtils

agents.each do |agent|
  path_separator = agent.platform_defaults[:pathseparator]
  initial_environment = on(agent, puppet("config print environment")).stdout.chomp
  initial_environment_paths = on(agent, puppet("config print environmentpath")).stdout.chomp.split(path_separator)

  default_environment_path = ''
  custom_environment_path = agent.tmpdir('custom_environment')

  teardown do
    step 'uninstall the module' do
      uninstall_i18n_demo_module(master)
      uninstall_i18n_demo_module(agent)
    end

    step 'Remove custom environment paths' do
      environment_paths = on(agent, puppet("config print environmentpath")).stdout.chomp
      environment_paths.split(path_separator).each do |path|
        agent.rm_rf(path) unless initial_environment_paths.include?(path)
      end

      agent.rm_rf(custom_environment_path)
    end

    step 'Reset environment settings' do
      on(agent, puppet("config set environmentpath #{initial_environment_paths.join(path_separator)}"))

      on(agent, puppet('config print lastrunfile')) do |command_result|
        agent.rm_rf(command_result.stdout)
      end

      if initial_environment == 'production'
        on(agent, puppet("config delete environment"))
      else
        on(agent, puppet("config set environment #{initial_environment}"))
      end

      on(agent, puppet("agent -t"))
    end
  end

  step 'Ensure a clean environment with default settings' do
    step 'Remove the lastrunfile which contains the last used agent environment' do
      on(agent, puppet('config print lastrunfile')) do |command_result|
        agent.rm_rf(command_result.stdout)
      end
    end

    step 'Change to the default environment setting' do
      on(agent, puppet("config delete environment"))
      on(agent, puppet("config print environment")) do |result|
        assert_match('production', result.stdout, "Default environment is not 'production' as expected")
      end
    end

    step 'Change to the default environmentpath setting and remove production folder' do
      on(agent, puppet("config delete environmentpath"))
      default_environment_path = on(agent, puppet("config print environmentpath")).stdout.chomp
      agent.rm_rf("#{default_environment_path}/production")
    end

    step 'Apply changes and expect puppet to create the production folder back' do
      on(agent, puppet("agent -t"))
      on(agent, "ls #{default_environment_path}") do |result|
        assert_match('production', result.stdout, "Default environment folder was not generated in last puppet run")
      end
    end
  end

  step 'Install a module' do
    install_i18n_demo_module(master)
  end

  step 'Expect output from the custom fact of the module' do
    on(agent, puppet("agent -t"), :acceptable_exit_codes => [0, 2]) do |result|
      assert_match(/Error:.*i18ndemo/, result.stderr)
    end
  end

  step 'Add a custom environment path before the current one' do
    current_environment_path = on(agent, puppet("config print environmentpath")).stdout.chomp
    on(agent, puppet("config set environmentpath '#{custom_environment_path}#{path_separator}#{current_environment_path}'"))
  end

  step 'Expect the module to still be found' do
    on(agent, puppet("agent -t"), :acceptable_exit_codes => [0, 2]) do |result|
      assert_match(/Error:.*i18ndemo/, result.stderr)
    end
  end

  step 'Expect no production environment folder changes' do
    on(agent, "ls #{custom_environment_path}") do |result|
      refute_match(/production/, result.stdout)
    end

    on(agent, "ls #{default_environment_path}") do |result|
      assert_match('production', result.stdout)
    end
  end

  step 'Remove production folder' do
    agent.rm_rf("#{default_environment_path}/production")
  end

  step 'Expect production environment folder to be recreated in the custom path' do
    on(agent, puppet("agent -t"), :acceptable_exit_codes => [0, 2]) do |result|
      step 'Expect the module to be gone on the server node' do
        refute_match(/Error:.*i18ndemo/, result.stderr)
      end if agent == master

      step 'Expect the production environment, along with the module, to be synced back on the agent node' do
        assert_match(/Error:.*i18ndemo/, result.stderr)
      end if agent != master
    end

    on(agent, "ls #{custom_environment_path}") do |result|
      assert_match('production', result.stdout, "Default environment folder was not generated in last puppet run")
    end

    on(agent, "ls #{default_environment_path}") do |result|
      refute_match(/production/, result.stdout)
    end
  end

  step 'Set back to just default environmentpath setting' do
    on(agent, puppet("config delete environmentpath"))
  end

  step 'Expect production environment folder to be found in both paths but use the default one' do
    on(agent, puppet("agent -t"), :acceptable_exit_codes => [0, 2]) do |result|
      step 'Expect the module to be gone' do
        refute_match(/Error:.*i18ndemo/, result.stderr)
      end if agent == master
    end

    on(agent, "ls #{default_environment_path}") do |result|
      assert_match('production', result.stdout, "Default environment folder was not generated in last puppet run")
    end

    on(agent, "ls #{custom_environment_path}") do |result|
      assert_match('production', result.stdout)
    end
  end
end
