test_name "puppet module install (with necessary dependency upgrade)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

default_moduledir = get_default_modulepath_for_host(master)

step "Install an older module version"
module_version = '1.6.0'
on master, puppet("module install #{module_author}-#{module_name} --version #{module_version}") do
  assert_match(/#{module_author}-#{module_name} \(.*v#{module_version}.*\)/, stdout,
        "Notice of specific version installed was not displayed")
end
on master, "grep \"version '#{module_version}'\" #{default_moduledir}/#{module_name}/Modulefile"


step "Install a module that requires the older module dependency be upgraded"
on master, puppet("module install #{module_author}-apollo") do
  assert_module_installed_ui(stdout, module_author, module_name, module_version, '>')
end

on master, puppet("module list --modulepath #{default_moduledir}") do
  assert_module_installed_ui(stdout, module_author, module_name, module_version, '>')
end
