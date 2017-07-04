test_name "puppet module install (with unsatisfied constraints)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

module_author = "pmtacceptance"
module_name   = "git"
module_reference = "#{module_author}-#{module_name}"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/crakorn',
  ]: ensure => directory;
  '#{master['distmoduledir']}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.0.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "#{module_author}/stdlub", "version_requirement": "1.x" }
      ]
    }';
}
PP

step "Try to install a module that has an unsatisfiable dependency"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/No version.*can satisfy all dependencies/, stderr,
        "Unsatisfiable dependency error was not displayed")
  assert_match(/Use `puppet module install --ignore-dependencies/, stderr,
        "Use --ignore-dependencies error was not displayed")
end
assert_module_not_installed_on_disk(master, module_name)

# FIXME I don't understand what behaviour this looking for?
step "Install the module with an unsatisfiable dependency"
on master, puppet("module install #{module_author}-#{module_name} --ignore-dependencies") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, module_name)

step "Try to install a specific version of the unsatisfiable dependency"
on master, puppet("module install #{module_author}-stdlub --version 1.x"), :acceptable_exit_codes => [1] do
  assert_match(/No version.* can satisfy all dependencies/, stderr,
        "Unsatisfiable dependency was not displayed")
end
assert_module_not_installed_on_disk(master, 'stdlub')

step "Try to install any version of the unsatisfiable dependency"
on master, puppet("module install #{module_author}-stdlub"), :acceptable_exit_codes => [1] do
  assert_match(/No version.* can satisfy all dependencies/, stderr,
        "Unsatisfiable dependency was not displayed")
end
assert_module_not_installed_on_disk(master, 'stdlub')

step "Install the unsatisfiable dependency with --force"
on master, puppet("module install #{module_author}-stdlub --force") do
  assert_module_installed_ui(stdout, module_author, 'stdlub')
end
assert_module_installed_on_disk(master, 'stdlub')
