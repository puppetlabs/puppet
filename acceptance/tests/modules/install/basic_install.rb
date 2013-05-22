test_name "puppet module install (agent)"

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  modulesdir = agent.tmpdir('puppet_module_build')
  teardown do
    on agent, "rm -rf #{modulesdir}"
  end

  step "install module to '#{modulesdir}'"
  on(agent, puppet("module install pmtacceptance-nginx  --target-dir='#{modulesdir}'")) do
    assert_match(/#{modulesdir}\n└── pmtacceptance-nginx \(.*\)/, stdout)
  end
end
