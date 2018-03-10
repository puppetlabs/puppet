test_name 'C100565: puppet agent with module should translate messages' do
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
  step "configure server locale to #{language}" do
    configure_master_system_locale(language)
  end

  app_type          = File.basename(__FILE__, '.*')
  tmp_environment_1 = mk_tmp_environment_with_teardown(master, app_type)

  step 'install a i18ndemo module' do
    install_i18n_demo_module(master, tmp_environment_1)
  end

  teardown do
    step 'resetting the server locale' do
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
    skip_test('on windows this test only works on a machine with a japanese code page set') if agent['platform'] =~ /windows/ && agent['locale'] != 'ja'

    agent_language = enable_locale_language(agent, language)
    skip_test("test machine is missing #{agent_language} locale. Skipping") if agent_language.nil?
    shell_env_language = { 'LANGUAGE' => agent_language, 'LANG' => agent_language }

    type_path = agent.tmpdir('provider')
    teardown do
      on(agent, "rm -rf '#{type_path}'")
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
        create_sitepp(master, tmp_environment_1, site_pp_content_1)
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => shell_env_language), :acceptable_exit_codes => [0, 2]) do |result|
          assert_match(/Error:.*\w+-i18ndemo fact: これは\w+-i18ndemoからのカスタムファクトからのレイズです/, result.stderr, 'missing translation for raise from ruby fact')
        end
      end

      step 'verify translations from init.pp' do
        # TODO This test needs to be updated with the proper translation and re-enabled when translations for the affected strings are updated.
        # site_pp_content_3 = <<-PP
        #   node default {
        #     class { 'i18ndemo': param1 => false }
        #   }
        # PP
        # create_sitepp(master, tmp_environment_1, site_pp_content_3)
        # on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => { 'LANGUAGE' => '', 'LANG' => language }), :acceptable_exit_codes => 1) do |result|
        #   assert_match(/Error: リモートサーバからカタログを取得できませんでした: SERVERのエラー500 : サーバエラー: Evaluation/, result.stderr, 'missing translation for Server Error')
        #   assert_match(/Error:.*の検証中にエラーが生じました。.*ファイルの作成に失敗しました/, result.stderr, 'missing translation for fail from init.pp')
        # end
      end

      step 'verify custom type translations' do
        site_pp_content_4 = <<-PP
          node default {
            i18ndemo_type { 'hello': }
          }
        PP

        create_sitepp(master, tmp_environment_1, site_pp_content_4)
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |result|
          assert_match(/Warning:.*\w+-i18ndemo type: 良い値/, result.stderr, 'missing warning from custom type')
        end

        site_pp_content_5 = <<-PP
          node default {
            i18ndemo_type { '12345': }
          }
        PP
        create_sitepp(master, tmp_environment_1, site_pp_content_5)
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |result|
          assert_match(/Error: .* \w+-i18ndemo type: 値は有12345効な値ではありません/, result.stderr, 'missing error from invalid value for custom type param')
        end
      end

      step 'verify custom provider translation' do
        site_pp_content_6 = <<-PP
          node default {
            i18ndemo_type { 'hello': 
              ensure => present, 
              dir => '#{type_path}',
            }
          }
        PP
        create_sitepp(master, tmp_environment_1, site_pp_content_6)
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => shell_env_language)) do |result|
          assert_match(/Warning:.*\w+-i18ndemo provider: i18ndemo_typeは存在しますか/, result.stderr, 'missing translated provider message')
        end
      end

      step 'verify function string translation' do
        site_pp_content_7 = <<-PP
          node default {
            notify { 'happy': 
              message => happyfuntime('happy') 
            }
          }
        PP
        create_sitepp(master, tmp_environment_1, site_pp_content_7)
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment_1}", 'ENV' => shell_env_language), :acceptable_exit_codes => 2) do |result|
          assert_match(/Notice: --\*\w+-i18ndemo function: それは楽しい時間です\*--/, result.stdout, 'missing translated notice message')
        end
      end
    end
  end
end