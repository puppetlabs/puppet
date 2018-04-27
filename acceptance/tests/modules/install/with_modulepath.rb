# encoding: UTF-8

test_name "puppet module install (with modulepath)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

codedir = puppet_config(master, 'codedir', section: 'master')
module_author = "pmtacceptance"
module_name   = "nginx"

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
  # TODO: make helper take modulepath
  on master, "rm -rf #{codedir}/modules2"
end

step 'Setup'

stub_forge_on(master)

on master, "mkdir -p #{codedir}/modules2"

step "Install a module with relative modulepath"
on master, "cd #{codedir}/modules2 && puppet module install #{module_author}-#{module_name} --modulepath=." do
  assert_module_installed_ui(stdout, module_author, module_name)
  assert_match(/#{codedir}\/modules2/, stdout,
        "Notice of non default install path was not displayed")
end
assert_module_installed_on_disk(master, module_name, "#{codedir}/modules2")

step "Install a module with absolute modulepath"
on master, "test -d #{codedir}/modules2/#{module_name} && rm -rf #{codedir}/modules2/#{module_name}"
on master, puppet("module install #{module_author}-#{module_name} --modulepath=#{codedir}/modules2") do
  assert_module_installed_ui(stdout, module_author, module_name)
  assert_match(/#{codedir}\/modules2/, stdout,
        "Notice of non default install path was not displayed")
end
assert_module_installed_on_disk(master, module_name, "#{codedir}/modules2")
