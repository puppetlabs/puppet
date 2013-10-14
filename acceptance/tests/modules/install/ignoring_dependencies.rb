test_name "puppet module install (ignoring dependencies)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies   = ["stdlib"]

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'
stub_forge_on(master)

step "Install a module, but ignore dependencies"
on master, puppet("module install #{module_author}-#{module_name} --ignore-dependencies") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
module_dependencies.each do |dependency|
  assert_module_not_installed_on_disk(master, master['distmoduledir'], dependency)
end
