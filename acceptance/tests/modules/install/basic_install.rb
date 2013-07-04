test_name "puppet module install (agent)"

module_author = "pmtacceptance"
module_name = "nginx"
module_dependencies   = []

teardown do
  on master, "rm -rf #{master['distmoduledir']}/*"
  agents.each do |agent|
    on agent, "rm -rf #{agent['distmoduledir']}/*"
  end
  on master, "rm -rf #{master['sitemoduledir']}/#{module_name}"
  module_dependencies.each do |dependency|
    on master, "rm -rf #{master['sitemoduledir']}/#{dependency}"
  end
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  step "install module '#{module_author}-#{module_name}'"
  on(agent, puppet("module install #{module_author}-#{module_name}")) do
    assert_match(/#{module_author}-#{module_name}/, stdout,
          "Module name not displayed during install")
    assert_match(/Notice: Installing -- do not interrupt/, stdout,
          "No installing notice displayed!")
  end

  step "check for a '#{module_name}' manifest"
    on(agent, "[ -f #{agent['distmoduledir']}/#{module_name}/manifests/init.pp ]")


end
