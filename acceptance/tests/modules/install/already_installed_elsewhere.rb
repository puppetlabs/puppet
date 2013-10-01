test_name "puppet module install (already installed elsewhere)"
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
file {
  [
    '#{master['distmoduledir']}',
    '#{master['sitemoduledir']}',
    '#{master['sitemoduledir']}/#{module_name}',
  ]: ensure => directory;
  '#{master['sitemoduledir']}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}/#{module_name}",
      "version": "0.0.1",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

step "Try to install a module that is already installed"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/#{module_author}-#{module_name}.*is already installed/, stderr,
        "Error that module was already installed was not displayed")
end
assert_module_not_installed_on_disk(master, master['distmoduledir'], module_name)

step "Try to install a specific version of a module that is already installed"
on master, puppet("module install #{module_author}-#{module_name} --version 1.x"), :acceptable_exit_codes => [1] do
  assert_match(/Could not install module '#{module_author}-#{module_name}' \(v1.x\)/, stderr,
        "Error that specified module version could not be installed was not displayed")
  assert_match(/#{module_author}-#{module_name}.*is already installed/, stderr,
        "Error that module was already installed was not displayed")
end
assert_module_not_installed_on_disk(master, master['distmoduledir'], module_name)

step "Install a module that is already installed (with --force)"
on master, puppet("module install #{module_author}-#{module_name} --force") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
