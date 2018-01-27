test_name 'C100573: puppet application/face with module translates messages' do
  confine :except, :platform => /^eos-/ # translation not supported
  confine :except, :platform => /^cisco/ # translation not supported
  confine :except, :platform => /^cumulus/ # translation not supported
  confine :except, :platform => /^solaris/ # translation not supported

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  require 'puppet/acceptance/i18ndemo_utils'
  extend Puppet::Acceptance::I18nDemoUtils

  language = 'ja_JP'

  agents.each do |agent|
    skip_test('on windows this test only works on a machine with a japanese code page set') if agent['platform'] =~ /windows/ && agent['locale'] != 'ja'

    # REMIND - It was noted that skipping tests on certain platforms sometimes causes
    # beaker to mark the test as a failed even if the test succeeds on other targets. 
    # Hence we just print a message and skip w/o telling beaker about it.
    if on(agent, facter("fips_enabled")).stdout =~ /true/
      puts "Module build, loading and installing is not supported on fips enabled platforms"
      next
    end

    agent_language = enable_locale_language(agent, language)
    skip_test("test machine is missing #{agent_language} locale. Skipping") if agent_language.nil?
    shell_env_language = { 'LANGUAGE' => agent_language, 'LANG' => agent_language }

    step 'install a i18ndemo module' do
      install_i18n_demo_module(agent)
    end

    teardown do
      uninstall_i18n_demo_module(agent)
    end

    step "Run puppet i18ndemo (face/application from a module with language #{agent_language} and verify the translations" do
      step 'puppet --help contains i18ndemo summary translation' do
        on(agent, puppet('--help', 'ENV' => shell_env_language)) do |result|
          assert_match(/\s*i18ndemo\s+\w+-i18ndemo face: I18ndemoモジュールの人形の顔の例/, result.stdout, 'missing translation of i18ndemo help summary')
        end
      end

      step 'puppet i18ndemo --help contains test_face summary' do
        on(agent, puppet('i18ndemo --help', 'ENV' => shell_env_language)) do |result|
          assert_match(/\s*test_face\s+\w+-i18ndemo face: test_faceアクションのヘルプの要約/, result.stdout, 'missing translation of i18ndemo face help summary')
        end
      end

      step 'puppet i18ndemo test_face contains translated warning' do
        on(agent, puppet('i18ndemo', 'ENV' => shell_env_language)) do |result|
          assert_match(/Warning: \w+-i18ndemo face: i18ndemo test_faceが呼び出されました/, result.stderr, 'missing translation of Warning message from i18ndemo face')
        end
      end
    end
  end
end
