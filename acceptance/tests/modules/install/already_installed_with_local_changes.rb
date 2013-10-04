test_name "puppet module install (already installed with local changes)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_reference = "#{module_author}-#{module_name}"
module_path = "#{master['distmoduledir']}/#{module_name}"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup' do
  stub_forge_on(master)
end

step "Check that module is not installed" do
  on master, %Q{[ ! -d "#{module_path}" ]}
end

step "Install module" do
  on master, puppet("module install #{module_reference}")
  assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
end

step "Make local changes in installed module" do
  on master, "echo 'changed' >> #{module_path}/README"
end

step "Try to install a module that is already installed" do
  on master, puppet("module install #{module_reference}"), :acceptable_exit_codes => [1] do
    assert_match(/#{module_reference}.*is already installed/, stderr,
          "Error that module was already installed was not displayed")
    assert_match(/changes made locally/, stderr,
          "Error that module has local changes was not displayed")
  end
  assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
end

step "Try to install a specific version of a module that is already installed" do
  on master, puppet("module install #{module_reference} --version 1.x"), :acceptable_exit_codes => [1] do
    assert_match(/Could not install module '#{module_reference}' \(v1.x\)/, stderr,
          "Error that specified module version could not be installed was not displayed")
    assert_match(/#{module_reference}.*is already installed/, stderr,
          "Error that module was already installed was not displayed")
    assert_match(/changes made locally/, stderr,
          "Error that module has local changes was not displayed")
  end
  assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
end

step "Install a module that is already installed (with --force)" do
  on master, puppet("module install #{module_reference} --force") do
    assert_module_installed_ui(stdout, module_author, module_name)
  end
  assert_module_installed_on_disk(master, master['distmoduledir'], module_name)
  #validate checksum
end
