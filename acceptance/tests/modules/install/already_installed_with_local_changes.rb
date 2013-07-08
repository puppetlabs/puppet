test_name "puppet module install (already installed with local changes)"
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
    '#{master['distmoduledir']}/#{module_name}',
  ]: ensure => directory;
  '#{master['distmoduledir']}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}/#{module_name}",
      "version": "0.0.1",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "checksums": {
        "README": "2a3adc3b053ef1004df0a02cefbae31f"
      },
      "dependencies": []
    }';
  '#{master['distmoduledir']}/#{module_name}/README':
    content => '#{module_name} module';
}
PP


step "Try to install a module that is already installed"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/#{module_author}-#{module_name}.*is already installed/, stderr,
        "Error that module was already installed was not displayed")
  assert_match(/changes made locally/, stderr,
        "Error that module has local changes was not displayed")
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"

step "Try to install a specific version of a module that is already installed"
on master, puppet("module install #{module_author}-#{module_name} --version 1.x"), :acceptable_exit_codes => [1] do
  assert_match(/Could not install module '#{module_author}-#{module_name}' \(v1.x\)/, stderr,
        "Error that specified module version could not be installed was not displayed")
  assert_match(/#{module_author}-#{module_name}.*is already installed/, stderr,
        "Error that module was already installed was not displayed")
  assert_match(/changes made locally/, stderr,
        "Error that module has local changes was not displayed")
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"

step "Install a module that is already installed (with --force)"
on master, puppet("module install #{module_author}-#{module_name} --force") do
  assert_match(/Installing -- do not interrupt/, stdout,
        "Notice that module was installing was not displayed")
  assert_match(/#{module_author}-#{module_name}/, stdout,
        "Notice that module '#{module_author}-#{module_name}' was installed was not displayed")
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"
#validate checksum
