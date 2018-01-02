test_name 'C100561: verify that disable_i18n can be set to true and have translations disabled' do
  confine :except, :platform => /^eos-/ # translation not supported
  confine :except, :platform => /^cisco_/ # translation not supported
  confine :except, :platform => /^cumulus/ # translation not supported
  confine :except, :platform => /^solaris/ # translation not supported
  confine :except, :platform => /^aix/ # QENG-5283 needed for this to work

  tag 'risk:medium',
      'audit:acceptance'

  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  language = 'ja_JP'
  agents.each do |agent|

    puppet_conf = agent.tmpfile('puppet_conf_test')
    config      = <<-EOM
    [user]
    disable_i18n = true
    EOM
    create_remote_file(agent, puppet_conf, config)

    teardown do
      on(agent, "rm -f '#{puppet_conf}'")
    end

    step("ensure #{language} locale is configured") do
      language = enable_locale_language(agent, language)
      # fall back to ja_JP since we're expecting english fallback for this test anyways
      language = 'ja_JP' if language.nil?
    end

    step "Run Puppet agent with language #{language} and check the output" do
      on(agent, puppet("agent -t --config '#{puppet_conf}' --server '#{master}'", 'ENV' => {'LANGUAGE' => language})) do |agent_result|
        assert_match(/Applying configuration version '[^']*'/, agent_result.stdout, "agent run does not contain english 'Applying configuration version'")
        assert_match(/Applied catalog in\s+[0-9.]*\s+seconds/, agent_result.stdout, "agent run does not contain english 'Applied catalog in' ")
      end
    end
  end
end
