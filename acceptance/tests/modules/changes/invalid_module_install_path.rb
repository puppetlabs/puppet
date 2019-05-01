test_name "puppet module changes (on an invalid module install path)" do

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    testdir = agent.tmpdir("module_changes_with_invalid_path")
    step "Run module changes on an invalid module install path" do
      on(agent, puppet("module changes #{testdir}/nginx"),
         acceptable_exit_codes: [1]) do
        pattern = Regexp.new([
          ".*Error: Could not find a valid module at \"#{testdir}/nginx\".*",
          ".*Error: Try 'puppet help module changes' for usage.*"
        ].join("\n"), Regexp::MULTILINE)
        assert_match(pattern, result.stderr)
      end
    end
  end
end
