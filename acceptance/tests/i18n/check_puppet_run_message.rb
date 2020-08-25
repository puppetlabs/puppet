test_name 'C100559: puppet agent run output with a supported language should be localized' do
  confine :except, :platform => /^solaris/ # translation not supported
  confine :except, :platform => /^aix/     # QENG-5283 needed for this to work

  skip_test "Localization files are unavailable"

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  agents.each do |agent|
    language = 'ja_JP'

    step("ensure #{language} locale is configured") do
      language = enable_locale_language(agent, language)
      skip_test("test machine is missing #{language} locale. Skipping") if language.nil?
    end

    step "Run Puppet apply with language #{language} and check the output" do
      on(agent, puppet("agent -t", 'ENV' => {'LANGUAGE' => language})) do |apply_result|
        # Info: Applying configuration version '1505773208'
        assert_match(/設定バージョン'[^']*'を適用しています。/, apply_result.stdout, "agent run does not contain 'Applying configuration version' translation")
        # Notice: Applied catalog in 0.03 seconds
        assert_match(/[0-9.]*\s*秒でカタログを適用しました。/, apply_result.stdout, "agent run does not contain 'Applied catalog in #.## seconds' translation")
      end
    end
  end
end
