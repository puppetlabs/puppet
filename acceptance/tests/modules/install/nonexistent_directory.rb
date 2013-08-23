test_name "puppet module install (nonexistent directory)"
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

apply_manifest_on master, <<-PP
  file { '/tmp/modules': ensure => absent, recurse => true, force => true }
PP

step "Try to install a module to a non-existent directory"
on master, puppet("module install #{module_author}-#{module_name} --target-dir /tmp/modules") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, '/tmp/modules', module_name)

step "Try to install a module to a non-existent implicit directory"
# This test relies on destroying the default module directory...
on master, "mv #{master['distmoduledir']} #{master['distmoduledir']}-bak"
on master, puppet("module install #{module_author}-#{module_name}") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
# Restore default module directory...
on master, "mv #{master['distmoduledir']}-bak #{master['distmoduledir']}"
