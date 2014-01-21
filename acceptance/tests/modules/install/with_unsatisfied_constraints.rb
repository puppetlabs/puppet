test_name "puppet module install (with unsatisfied constraints)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "git"
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
  ]: making_sure => directory;
  '#{master['distmoduledir']}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.0.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "#{module_author}/stdlib", "version_requirement": "1.x" }
      ]
    }';
}
PP

step "Try to install a module that has an unsatisfiable dependency"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/No version.*will satisfy dependencies/, stderr,
        "Unsatisfiable dependency error was not displayed")
  assert_match(/Use `puppet module install --ignore-dependencies/, stderr,
        "Use --ignore-dependencies error was not displayed")
end
on master, "[ ! -d #{master['distmoduledir']}/#{module_name} ]"

step "Install the module with an unsatisfiable dependency"
on master, puppet("module install #{module_author}-#{module_name} --ignore-dependencies") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"

step "Try to install a specific version of the unsatisfiable dependency"
on master, puppet("module install #{module_author}-stdlib --version 1.x"), :acceptable_exit_codes => [1] do
  assert_match(/You specified '[^']+' \([^)]+\)[^']+'[^']+' \([^)]+\) requires/, stderr,
        "Unsatisfiable dependency for specific version error was not displayed")
end
on master, "[ ! -d #{master['distmoduledir']}/stdlib ]"

step "Try to install any version of the unsatisfiable dependency"
on master, puppet("module install #{module_author}-stdlib"), :acceptable_exit_codes => [1] do
  assert_match(/You specified '[^']+' \([^)]+\)[^']+'[^']+' \([^)]+\) requires/, stderr,
        "Unsatisfiable dependency for specific version error was not displayed")
end
on master, "[ ! -d #{master['distmoduledir']}/stdlib ]"

step "Install the unsatisfiable dependency with --force"
on master, puppet("module install #{module_author}-stdlib --force") do
  assert_module_installed_ui(stdout, module_author, 'stdlib')
end
on master, "[ -d #{master['distmoduledir']}/stdlib ]"
