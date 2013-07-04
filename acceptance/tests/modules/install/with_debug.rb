test_name "puppet module install (with debug)"

module_author = "pmtacceptance"
module_name   = "java"
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

step 'Setup'

stub_forge_on(master)

step "Install a module with debug output"
on master, puppet("module install #{module_author}-#{module_name} --debug") do
  assert_match(/Debug: Executing/, stdout,
          "No 'Debug' output displayed!")
end
