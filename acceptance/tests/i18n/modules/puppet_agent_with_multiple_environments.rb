test_name 'C100575: puppet agent with different modules in different environments should translate based on their module' do
  confine :except, :platform => /^eos-/ # translation not supported
  confine :except, :platform => /^cisco/ # translation not supported
  confine :except, :platform => /^cumulus/ # translation not supported
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

  app_type_1        = File.basename(__FILE__, '.*') + "_env_1"
  app_type_2        = File.basename(__FILE__, '.*') + "_env_2"
  tmp_environment_1 = mk_tmp_environment_with_teardown(master, app_type_1)
  tmp_environment_2 = mk_tmp_environment_with_teardown(master, app_type_2)
  full_path_env_1 = File.join('/tmp', tmp_environment_1)
  full_path_env_2 = File.join('/tmp', tmp_environment_2)
  tmp_po_file = master.tmpfile('tmp_po_file')

  step 'install a i18ndemo module' do
    install_i18n_demo_module(master, tmp_environment_1)
    install_i18n_demo_module(master, tmp_environment_2)
  end

  step "configure server locale to #{language}" do
    configure_master_system_locale(language)
  end

  teardown do
    on(master, "rm -f '#{tmp_po_file}'")
    step 'uninstall the module' do
      agents.each do |agent|
        uninstall_i18n_demo_module(agent)
      end
      uninstall_i18n_demo_module(master)
    end
    step 'resetting the server locale' do
      reset_master_system_locale
    end
  end

  agents.each do |agent|
    skip_test('on windows this test only works on a machine with a japanese code page set') if agent['platform'] =~ /windows/ && agent['locale'] != 'ja'

    agent_language = enable_locale_language(agent, language)
    skip_test("test machine is missing #{agent_language} locale. Skipping") if agent_language.nil?
    shell_env_language = { 'LANGUAGE' => agent_language, 'LANG' => agent_language }

    env_1_po_file = File.join(full_path_env_1, 'modules', I18NDEMO_NAME, 'locales', 'ja', "#{I18NDEMO_MODULE_NAME}.po")
    on(master, "sed -e 's/\\(msgstr \"\\)\\([^\"]\\)/\\1'\"ENV_1\"':\\2/' #{env_1_po_file} > #{tmp_po_file} && mv #{tmp_po_file} #{env_1_po_file}")
    env_2_po_file = File.join(full_path_env_2, 'modules', I18NDEMO_NAME, 'locales', 'ja', "#{I18NDEMO_MODULE_NAME}.po")
    on(master, "sed -e 's/\\(msgstr \"\\)\\([^\"]\\)/\\1'\"ENV_2\"':\\2/' #{env_2_po_file} > #{tmp_po_file} && mv #{tmp_po_file} #{env_2_po_file}")
    on(master, "chmod a+r '#{env_1_po_file}' '#{env_2_po_file}'")

    step 'verify function string translation' do
      site_pp_content = <<-PP
          node default {
            notify { 'happy':
              message => happyfuntime('happy')
            }
          }
      PP
      create_sitepp(master, tmp_environment_1, site_pp_content)
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => shell_env_language), :acceptable_exit_codes => 2) do |result|
        assert_match(/Notice: --\*ENV_1:\w+-i18ndemo function: それは楽しい時間です\*--/, result.stdout, 'missing translated notice message for environment 1')
      end

      create_sitepp(master, tmp_environment_2, site_pp_content)
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_2}", 'ENV' => shell_env_language), :acceptable_exit_codes => 2) do |result|
        assert_match(/Notice: --\*ENV_2:\w+-i18ndemo function: それは楽しい時間です\*--/, result.stdout, 'missing translated notice message for environment 2')
      end
    end
  end
end
