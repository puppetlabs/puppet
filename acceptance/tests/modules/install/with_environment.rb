test_name 'puppet module install (with environment)'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

puppet_conf = generate_base_legacy_and_directory_environments(master['puppetpath'])

check_module_install_in = lambda do |environment, environment_path|
  on master, "puppet module install #{module_author}-#{module_name} --config=#{puppet_conf} --environment=#{environment}" do
    assert_module_installed_ui(stdout, module_author, module_name)
    assert_match(/#{environment_path}/, stdout,
          "Notice of non default install path was not displayed")
  end
  assert_module_installed_on_disk(master, "#{environment_path}", module_name)
end

step 'Install a module into a non default legacy environment' do
  check_module_install_in.call('legacyenv', "#{master['puppetpath']}/legacyenv/modules")
end

step 'Install a module into a non default directory environment' do
  check_module_install_in.call('direnv', "#{master['puppetpath']}/environments/direnv/modules")
end
