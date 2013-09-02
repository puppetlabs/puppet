test_name "puppet module upgrade (with environment)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = ["stdlib"]

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
  # TODO make helper take environments into account
  on master, "rm -rf #{master['puppetpath']}/testenv #{master['puppetpath']}/puppet2.conf"
end

step 'Setup'

stub_forge_on(master)

# Configure a non-default environment
apply_manifest_on master, %Q{
  file {
    [
      '#{master['puppetpath']}/testenv',
      '#{master['puppetpath']}/testenv/modules',
    ]:
      ensure => directory,
  }
  file {
    '#{master['puppetpath']}/puppet2.conf':
      source => $settings::config,
  }
}
on master, "{ echo '[testenv]'; echo 'modulepath=#{master['puppetpath']}/testenv/modules'; } >> #{master['puppetpath']}/puppet2.conf"

on master, puppet("module install #{module_author}-#{module_name} --config=#{master['puppetpath']}/puppet2.conf --version 1.6.0 --environment=testenv") do
  assert_module_installed_ui(stdout, module_author, module_name)
end

step "Upgrade a module that has a more recent version published"
on master, puppet("module upgrade #{module_author}-#{module_name} --config=#{master['puppetpath']}/puppet2.conf --environment=testenv") do
  assert_module_installed_ui(stdout, module_author, module_name)
  on master, "[ -f #{master['puppetpath']}/testenv/modules/#{module_name}/Modulefile ]"
  on master, "grep 1.7.1 #{master['puppetpath']}/testenv/modules/#{module_name}/Modulefile"
end
