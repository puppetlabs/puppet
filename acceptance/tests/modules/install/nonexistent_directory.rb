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
  assert_match(/Installing -- do not interrupt/, stdout,
        "Notice that module was installing was not displayed")
  assert_match(/#{module_author}-#{module_name}/, stdout,
        "Notice that module '#{module_author}-#{module_name}' was installed was not displayed")
end
on master, "[ -d /tmp/modules/#{module_name} ]"

step "Try to install a module to a non-existent implicit directory"
# This test relies on destroying the default module directory...
on master, "mv #{master['distmoduledir']} #{master['distmoduledir']}-bak"
on master, puppet("module install #{module_author}-#{module_name}") do
  assert_match(/Installing -- do not interrupt/, stdout,
        "Notice that module was installing was not displayed")
  assert_match(/#{module_author}-#{module_name}/, stdout,
        "Notice that module '#{module_author}-#{module_name}' was installed was not displayed")
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"
# Restore default module directory...
on master, "mv #{master['distmoduledir']}-bak #{master['distmoduledir']}"
