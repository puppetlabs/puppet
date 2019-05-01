test_name "puppet module changes (module missing metadata.json)" do

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    testdir = agent.tmpdir("module_changes_on_invalid_metadata")
    step "Setup" do
      apply_manifest_on agent, <<~MANIFEST
        file { '#{testdir}/nginx': ensure => directory }
      MANIFEST
    end

    step "Run module changes on a module which is missing metadata.json" do
      on(agent, puppet("module changes #{testdir}/nginx"),
         acceptable_exit_codes: [1]) do

        pattern = Regexp.new([
          ".*Error: Could not find a valid module at.*",
          ".*Error: Try 'puppet help module changes' for usage.*"
        ].join("\n"), Regexp::MULTILINE)
        assert_match(pattern, result.stderr)
      end
    end
  end
end
