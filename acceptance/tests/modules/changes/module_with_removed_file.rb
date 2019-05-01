test_name "puppet module changes (module with a removed file)" do

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    testdir = agent.tmpdir("module_changes_with_removed_file")
    step "Setup" do
      stub_forge_on(agent)
      on agent, puppet("module install pmtacceptance-nginx --modulepath #{testdir}")
      on agent, "rm -rf #{testdir}/nginx/README"
    end

    step "Run module changes to check a module with a removed file" do
      on(agent, puppet("module changes #{testdir}/nginx"),
         acceptable_exit_codes: [0]) do |result|

        pattern = Regexp.new([
          ".*Warning: 1 files modified.*"
        ].join("\n"), Regexp::MULTILINE)
        assert_match(pattern, result.stderr)
        assert_equal("README\n", result.stdout)
      end
    end
  end
end
