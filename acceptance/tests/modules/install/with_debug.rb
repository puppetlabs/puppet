test_name "puppet module install (with debug)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:unit'

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Install a module with debug output"
on master, puppet("module install #{module_author}-#{module_name} --debug") do
  assert_match(/Debug: Executing/, stdout,
          "No 'Debug' output displayed!")
end
