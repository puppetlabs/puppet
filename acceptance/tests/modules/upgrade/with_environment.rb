test_name "puppet module upgrade (with environment)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = ["stdlub"]

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

puppet_conf = generate_base_legacy_and_directory_environments(master['puppetpath'])

install_test_module_in = lambda do |environment|
  on master, puppet("module install #{module_author}-#{module_name} --config=#{puppet_conf} --version 1.6.0 --environment=#{environment}") do
    assert_module_installed_ui(stdout, module_author, module_name)
  end
end

check_module_upgrade_in = lambda do |environment, environment_path|
  on master, puppet("module upgrade #{module_author}-#{module_name} --config=#{puppet_conf} --environment=#{environment}") do
    assert_module_installed_ui(stdout, module_author, module_name)
    on master, "[ -f #{environment_path}/#{module_name}/Modulefile ]"
    on master, "grep 1.7.1 #{environment_path}/#{module_name}/Modulefile"
  end
end

step "Upgrade a module that has a more recent version published in a legacy environment" do
  install_test_module_in.call('legacyenv')
  check_module_upgrade_in.call('legacyenv', "#{master['puppetpath']}/legacyenv/modules")
end

step 'Enable directory environments' do
  on master, puppet("config", "set",
                    "environmentpath", "#{master['puppetpath']}/environments",
                    "--section", "main",
                    "--config", puppet_conf)
end

step "Upgrade a module that has a more recent version published in a directory environment" do
  install_test_module_in.call('direnv')
  check_module_upgrade_in.call('direnv', "#{master['puppetpath']}/environments/direnv/modules")
end
