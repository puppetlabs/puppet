test_name "puppet module install (force ignores dependencies)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "php"
module_dependencies   = ["apache"]

orig_installed_modules = get_installed_modules_for_hosts hosts

teardown do
  installed_modules = get_installed_modules_for_hosts hosts
  rm_installed_modules_from_hosts orig_installed_modules, installed_modules
end

step 'Setup'

stub_forge_on(master)

step "Try to install an unsatisfiable module"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/No version of '#{module_author}-#{module_name}' will satisfy dependencies/, stderr,
        "Error that module dependencies could not be met was not displayed")
end
on master, "[ ! -d #{master['distmoduledir']}/#{module_name} ]"
on master, "[ ! -d #{master['distmoduledir']}/apache ]"
module_dependencies.each do |dependency|
  on master, "[ ! -d #{master['distmoduledir']}/#{dependency} ]"
end

step "Install an unsatisfiable module with force"
on master, puppet("module install #{module_author}-#{module_name} --force") do
  assert_match(/Installing -- do not interrupt/, stdout,
        "Notice that module was installing was not displayed")
  assert_match(/#{module_author}-#{module_name}/, stdout,
        "Notice that module '#{module_author}-#{module_name}' was installed was not displayed")
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"
module_dependencies.each do |dependency|
  on master, "[ ! -d #{master['distmoduledir']}/#{dependency} ]"
end
