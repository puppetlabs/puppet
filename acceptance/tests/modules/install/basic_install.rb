test_name "puppet module install (agent)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  modulesdir = agent.tmpdir('puppet_module_build')

  on(agent, 'groups') do
    on(agent, "chgrp #{stdout.split(' ').pop} #{modulesdir}")
  end

  teardown do
    on agent, "rm -rf #{modulesdir}"
  end

  step "install module to '#{modulesdir}'"
  on(agent, puppet("module install pmtacceptance-nginx  --target-dir='#{modulesdir}'")) do
    assert_match(/#{modulesdir}\n└── pmtacceptance-nginx \(.*\)/, stdout)
    assert_module_installed_on_disk(agent, modulesdir, 'nginx')
  end
end
