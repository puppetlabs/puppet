test_name "puppet module changes (on an unmodified module)" do

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    testdir = agent.tmpdir("module_changes_with_unmodified")
    step "Setup" do
      stub_forge_on(agent)
      on agent, puppet("module install pmtacceptance-nginx --modulepath #{testdir}")
    end

    step "Run module changes to check an unmodified module" do
      on(agent, puppet("module changes #{testdir}/nginx"),
         acceptable_exit_codes: [0]) do
        assert_match(/No modified files/, stdout)
      end
    end
  end
end
