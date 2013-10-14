test_name "puppet module install (agent)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  distmoduledir = on(agent, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

  step "install module '#{module_author}-#{module_name}'"
  on(agent, puppet("module install #{module_author}-#{module_name}")) do
    assert_module_installed_ui(stdout, module_author, module_name)
  end
  assert_module_installed_on_disk(agent, distmoduledir, module_name)
end
