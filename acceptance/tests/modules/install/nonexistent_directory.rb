test_name "puppet module install (nonexistent directory)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

default_moduledir = get_default_modulepath_for_host(master)

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  on master, "mv #{default_moduledir}-bak #{default_moduledir}", :acceptable_exit_codes => [0, 1]
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
assert_module_installed_on_disk(master, module_name, '/tmp/modules')

step "Try to install a module to a non-existent implicit directory"
# This test relies on destroying the default module directory...
on master, "mv #{default_moduledir} #{default_moduledir}-bak"
on master, puppet("module install #{module_author}-#{module_name}") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, module_name, default_moduledir)
