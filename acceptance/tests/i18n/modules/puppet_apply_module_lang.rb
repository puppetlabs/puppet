test_name 'C100574: puppet apply using a module should translate messages in a language not supported by puppet' do

  confine :except, :platform => /^cisco/ # translation not supported
  confine :except, :platform => /^windows/ # Can't print Finish on an English or Japanese code page

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  require 'puppet/acceptance/i18ndemo_utils'
  extend Puppet::Acceptance::I18nDemoUtils

  language='fi_FI'

  agents.each do |agent|
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
    type_path = agent.tmpdir('provider')

    teardown do
      uninstall_i18n_demo_module(agent)
      on(agent, "rm -rf '#{type_path}'")
    end

    step "Run puppet apply of a module with language #{agent_language} and verify default english returned" do
      step 'verify custom fact message translated and applied catalog message not translatated' do
        on(agent, puppet("apply -e \"class { 'i18ndemo': filename => '#{type_path}' }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Error: Facter: error while resolving custom fact "i18ndemo_fact": i18ndemo_fact: tämä on korotus mukautetusta tosiasiasta \w+-i18ndemo/,
                       apply_result.stderr, 'missing translated message for raise from ruby fact')
          assert_match(/Notice: Applied catalog in [0-9.]+ seconds/, apply_result.stdout, 'missing untranslated message for catalog applied')
        end
      end

      step 'verify warning translated from init.pp' do
        on(agent, puppet("apply -e \"class { 'i18ndemo': filename => '#{type_path}' }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Warning: .*I18ndemo-tiedoston luominen/, apply_result.stderr, 'missing translated warning from init.pp')
        end

        on(agent, puppet("apply -e \"class { 'i18ndemo': param1 => false }\"", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |apply_result|
          assert_match(/Error: .* tiedostoa ei voitu luoda./, apply_result.stderr, 'missing translated message for fail from init.pp')
        end
      end

      step 'verify custom type messages translated' do
        on(agent, puppet("apply -e \"i18ndemo_type { 'hello': }\"", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |apply_result|
          assert_match(/Warning: .* Hyvä arvo i18ndemo_type::name/, apply_result.stderr, 'missing translated warning from custom type')
        end

        on(agent, puppet("apply -e \"i18ndemo_type { '12345': }\"", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |apply_result|
          assert_match(/Error: .* Arvo 12345 ei ole kelvollinen arvo i18ndemo_type::name/, apply_result.stderr, 'missing translated error from invalid value for custom type param')
        end
      end

      step 'verify custom provider translation' do
        on(agent, puppet("apply -e \"i18ndemo_type { 'hello': ensure => present, dir => '#{type_path}', }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Warning: .* Onko i18ndemo_type olemassa\?/, apply_result.stderr, 'missing translated provider message')
        end
      end

      step 'verify function string translation' do
        on(agent, puppet("apply -e \"notify { 'happy': message => happyfuntime('happy') }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Notice: --\*SE ON HAUSKAA AIKAA\*--/, apply_result.stdout, 'missing translated notice message')
        end
      end
    end
  end
end
