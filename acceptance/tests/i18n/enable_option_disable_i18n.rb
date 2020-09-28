test_name 'Verify that disable_i18n can be set to true and have translations disabled' do
  confine :except, :platform => /^solaris/ # translation not supported

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  require 'puppet/acceptance/i18ndemo_utils'
  extend Puppet::Acceptance::I18nDemoUtils

  language = 'ja_JP'

  step "configure server locale to #{language}" do
    configure_master_system_locale(language)
  end

  tmp_environment = mk_tmp_environment_with_teardown(master, File.basename(__FILE__, '.*'))

  step 'install a i18ndemo module' do
    install_i18n_demo_module(master, tmp_environment)
  end

  disable_i18n_default_master = master.puppet['disable_i18n']
  teardown do
    step 'resetting the server locale' do
      on(master, puppet("config set disable_i18n #{ disable_i18n_default_master }"))
      reset_master_system_locale
    end
    step 'uninstall the module' do
      agents.each do |agent|
        uninstall_i18n_demo_module(agent)
      end
      uninstall_i18n_demo_module(master)
    end
  end

  agents.each do |agent|
    agent_language = enable_locale_language(agent, language)
    skip_test("test machine is missing #{agent_language} locale. Skipping") if agent_language.nil?
    shell_env_language = { 'LANGUAGE' => agent_language, 'LANG' => agent_language }

    disable_i18n_default_agent = agent.puppet['disable_i18n']
    teardown do
      on(agent, puppet("config set disable_i18n #{ disable_i18n_default_agent }"))
    end

    step 'enable i18n' do
      on(agent, puppet("config set disable_i18n false"))
      on(master, puppet("config set disable_i18n false"))
      reset_master_system_locale
    end

    step 'expect #{language} translation for a custom type' do
      site_pp_content = <<-PP
        node default {
          i18ndemo_type { '12345': }
        }
      PP
      create_sitepp(master, tmp_environment, site_pp_content)
      on(agent, puppet("agent -t --environment #{tmp_environment}", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |result|
        assert_match(/Error: .* \w+-i18ndemo type: 値は有12345効な値ではありません/, result.stderr, 'missing error from invalid value for custom type param')
      end
    end

    step 'disable i18n' do
      on(agent, puppet("config set disable_i18n true"))
      on(master, puppet("config set disable_i18n true"))
      reset_master_system_locale
    end

    step 'expect no #{language} translation for a custom type' do
      site_pp_content = <<-PP
        node default {
          i18ndemo_type { '12345': }
        }
      PP
      create_sitepp(master, tmp_environment, site_pp_content)
      on(agent, puppet("agent -t --environment #{tmp_environment}", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |result|
        assert_match(/Error: .* Value 12345 is not a valid value for i18ndemo_type\:\:name/, result.stderr)
      end
    end
  end
end
