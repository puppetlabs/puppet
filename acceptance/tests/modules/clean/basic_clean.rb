test_name "puppet module clean (agent)"

agents.each do |agent|
  modulesdir = agent.tmpdir('puppet_module_build')
  teardown do
    on agent, "rm -rf #{modulesdir}"
  end

  step "install module clean"
  on(agent, puppet("module clean")) do
    assert_match(/:status => "success", :msg => "Cleaned module cache."/, stdout)
  end
end
