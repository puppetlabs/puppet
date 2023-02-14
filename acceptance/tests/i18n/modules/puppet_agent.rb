test_name 'C100565: puppet agent with module should translate messages' do
  confine :except, :platform => /^solaris/ # translation not supported

  tag 'audit:high',
      'audit:acceptance'

  skip_test('i18n test module uses deprecated function; update module to resume testing.')
  # function validate_absolute_path used https://github.com/eputnam/eputnam-i18ndemo/blob/621d06d/manifests/init.pp#L15

  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  require 'puppet/acceptance/i18ndemo_utils'
  extend Puppet::Acceptance::I18nDemoUtils

  language = 'ja_JP'
  disable_i18n_default_master = master.puppet['disable_i18n']

  step 'enable i18n on master' do
    on(master, puppet("config set disable_i18n false"))
  end

  step "configure server locale to #{language}" do
    configure_master_system_locale(language)
  end

  tmp_environment = mk_tmp_environment_with_teardown(master, File.basename(__FILE__, '.*'))

  step 'install a i18ndemo module' do
    install_i18n_demo_module(master, tmp_environment)
  end

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
    agents.each do |agent|
      on(agent, puppet('config print lastrunfile')) do |command_result|
        agent.rm_rf(command_result.stdout)
      end
    end
  end

  agents.each do |agent|
    skip_test('on windows this test only works on a machine with a japanese code page set') if agent['platform'] =~ /windows/ && agent['locale'] != 'ja'

    agent_language = enable_locale_language(agent, language)
    skip_test("test machine is missing #{agent_language} locale. Skipping") if agent_language.nil?
    shell_env_language = { 'LANGUAGE' => agent_language, 'LANG' => agent_language }

    type_path = agent.tmpdir('provider')
    disable_i18n_default_agent = agent.puppet['disable_i18n']
    teardown do
      on(agent, puppet("config set disable_i18n #{ disable_i18n_default_agent }"))
      agent.rm_rf(type_path)
    end

    step 'enable i18n' do
      on(agent, puppet("config set disable_i18n false"))
    end

    step "Run puppet agent of a module with language #{agent_language} and verify the translations" do

      step 'verify custom fact translations' do
        site_pp_content_1 = <<-PP
          node default {
            class { 'i18ndemo':
              filename => '#{type_path}'
            }
          }
        PP

        create_sitepp(master, tmp_environment, site_pp_content_1)
        on(agent, puppet("agent -t --no-disable_i18n --environment #{tmp_environment}", 'ENV' => shell_env_language), :acceptable_exit_codes => [0, 2]) do |result|
          assert_match(/.*\w+-i18ndemo fact: これは\w+-i18ndemoからのカスタムファクトからのレイズです/, result.stderr, 'missing translation for raise from ruby fact')
        end
      end unless agent['platform'] =~ /ubuntu-16.04/ # Condition to be removed after FACT-2799 gets resolved

      step 'verify custom type translations' do
        site_pp_content_2 = <<-PP
          node default {
            i18ndemo_type { 'hello': }
          }
        PP

        create_sitepp(master, tmp_environment, site_pp_content_2)
        on(agent, puppet("agent -t --environment #{tmp_environment}", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |result|
          assert_match(/Warning:.*\w+-i18ndemo type: 良い値/, result.stderr, 'missing warning from custom type')
        end

        site_pp_content_3 = <<-PP
          node default {
            i18ndemo_type { '12345': }
          }
        PP
        create_sitepp(master, tmp_environment, site_pp_content_3)
        on(agent, puppet("agent -t --environment #{tmp_environment}", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |result|
          assert_match(/Error: .* \w+-i18ndemo type: 値は有12345効な値ではありません/, result.stderr, 'missing error from invalid value for custom type param')
        end
      end

      step 'verify custom provider translation' do
        site_pp_content_4 = <<-PP
          node default {
            i18ndemo_type { 'hello': 
              ensure => present, 
              dir => '#{type_path}',
            }
          }
        PP
        create_sitepp(master, tmp_environment, site_pp_content_4)
        on(agent, puppet("agent -t --environment #{tmp_environment}", 'ENV' => shell_env_language)) do |result|
          assert_match(/Warning:.*\w+-i18ndemo provider: i18ndemo_typeは存在しますか/, result.stderr, 'missing translated provider message')
        end
      end

      step 'verify function string translation' do
        site_pp_content_5 = <<-PP
          node default {
            notify { 'happy': 
              message => happyfuntime('happy') 
            }
          }
        PP
        create_sitepp(master, tmp_environment, site_pp_content_5)
        on(agent, puppet("agent -t --environment #{tmp_environment}", 'ENV' => shell_env_language), :acceptable_exit_codes => 2) do |result|
          assert_match(/Notice: --\*\w+-i18ndemo function: それは楽しい時間です\*--/, result.stdout, 'missing translated notice message')
        end
      end
    end
  end
end
