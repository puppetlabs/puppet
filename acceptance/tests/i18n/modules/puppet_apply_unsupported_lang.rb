test_name 'C100568: puppet apply of module for an unsupported language should fall back to english' do

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  require 'puppet/acceptance/i18ndemo_utils'
  extend Puppet::Acceptance::I18nDemoUtils

  unsupported_language='hu_HU'
  shell_env_language = { 'LANGUAGE' => unsupported_language, 'LANG' => unsupported_language }

  agents.each do |agent|
    # REMIND - It was noted that skipping tests on certain platforms sometimes causes
    # beaker to mark the test as a failed even if the test succeeds on other targets. 
    # Hence we just print a message and skip w/o telling beaker about it.
    if on(agent, facter("fips_enabled")).stdout =~ /true/
      puts "Module build, loading and installing is not supported on fips enabled platforms"
      next
    end

    step 'install a i18ndemo module' do
      install_i18n_demo_module(agent)
    end
    type_path = agent.tmpdir('provider')

    teardown do
      uninstall_i18n_demo_module(agent)
      on(agent, "rm -rf '#{type_path}'")
    end

    step "Run puppet apply of a module with language #{unsupported_language} and verify default english returned" do
      step 'verify custom fact messages not translatated' do
        on(agent, puppet("apply -e \"class { 'i18ndemo': filename => '#{type_path}' }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Error:.*i18ndemo_fact: this is a raise from a custom fact from \w+-i18ndemo/, apply_result.stderr, 'missing untranslated message for raise from ruby fact')
        end
      end

      step 'verify warning not translated from init.pp' do
        on(agent, puppet("apply -e \"class { 'i18ndemo': filename => '#{type_path}' }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Warning:.*Creating an i18ndemo file/, apply_result.stderr, 'missing untranslated warning from init.pp')
        end

        on(agent, puppet("apply -e \"class { 'i18ndemo': param1 => false }\"", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |apply_result|
          assert_match(/Error:.*Failed to create/, apply_result.stderr, 'missing untranslated message for fail from init.pp')
        end
      end

      step 'verify custom type messages not translated' do
        on(agent, puppet("apply -e \"i18ndemo_type { 'hello': }\"", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |apply_result|
          assert_match(/Warning:.*Good value for i18ndemo_type::name/, apply_result.stderr, 'missing untranslated warning from custom type')
        end

        on(agent, puppet("apply -e \"i18ndemo_type { '12345': }\"", 'ENV' => shell_env_language), :acceptable_exit_codes => 1) do |apply_result|
          assert_match(/Error:.*Value 12345 is not a valid value for i18ndemo_type::name/, apply_result.stderr, 'missing untranslated error from invalid value for custom type param')
        end
      end

      step 'verify custom provider translation' do
        on(agent, puppet("apply -e \"i18ndemo_type { 'hello': ensure => present, dir => '#{type_path}', }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Warning:.* Does i18ndemo_type exist\?/, apply_result.stderr, 'missing untranslated provider message')
        end
      end

      step 'verify function string translation' do
        on(agent, puppet("apply -e \"notify { 'happy': message => happyfuntime('happy') }\"", 'ENV' => shell_env_language)) do |apply_result|
          assert_match(/Notice: --\*IT'S HAPPY FUN TIME\*--/, apply_result.stdout, 'missing untranslated notice message')
        end
      end
    end
  end
end
