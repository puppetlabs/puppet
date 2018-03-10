test_name 'C100576: puppet describe with module type translates message' do
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

    step "Run puppet describe from a module with language #{agent_language} and verify the translations" do
      on(agent, puppet('describe i18ndemo_type', 'ENV' => shell_env_language)) do |result|
        assert_match(/\w+-i18ndemo type: dirパラメータは、検査するディレクトリパスをとります/, result.stdout, 'missing translation of dir parameter from i18ndemo_type')
        assert_match(/\w+-i18ndemo type: nameパラメータには、大文字と小文字の変数A-Za-zが使用されます/, result.stdout, 'missing translation of name parameter from i18ndemo_type')
      end
    end
  end
end
