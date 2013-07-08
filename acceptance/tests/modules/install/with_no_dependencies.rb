test_name "puppet module install (with no dependencies)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Install a module with no dependencies"
on master, puppet("module install #{module_author}-#{module_name}") do
  assert_match(/Installing -- do not interrupt/, stdout,
        "Notice that module was installing was not displayed")
  assert_match(/#{module_author}-#{module_name}/, stdout,
        "Notice that module '#{module_author}-#{module_name}' was installed was not displayed")
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"
