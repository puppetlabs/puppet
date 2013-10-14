test_name "puppet module install (force ignores dependencies)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "php"
module_dependencies   = ["apache"]

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Try to install an unsatisfiable module"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/No version of '#{module_author}-#{module_name}' will satisfy dependencies/, stderr,
        "Error that module dependencies could not be met was not displayed")
end
assert_module_not_installed_on_disk(master, master['distmoduledir'], module_name)
module_dependencies.each do |dependency|
  assert_module_not_installed_on_disk(master, master['distmoduledir'], dependency)
end

step "Install an unsatisfiable module with force"
on master, puppet("module install #{module_author}-#{module_name} --force") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
module_dependencies.each do |dependency|
  assert_module_not_installed_on_disk(master, master['distmoduledir'], dependency)
end
