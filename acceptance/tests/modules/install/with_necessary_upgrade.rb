test_name "puppet module install (with necessary dependency upgrade)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Install an older module version"
module_version = '1.6.0'
on master, puppet("module install #{module_author}-#{module_name} --version #{module_version}") do
  assert_match(/#{module_author}-#{module_name} \(.*v#{module_version}.*\)/, stdout,
        "Notice of specific version installed was not displayed")
end
on master, "grep \"version '#{module_version}'\" #{master['distmoduledir']}/#{module_name}/Modulefile"


step "Install a module that requires the older module dependency be upgraded"
on master, puppet("module install #{module_author}-apollo") do
  assert_module_installed_ui(stdout, module_author, module_name, module_version, '>')
end

on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_module_installed_ui(stdout, module_author, module_name, module_version, '>')
end
