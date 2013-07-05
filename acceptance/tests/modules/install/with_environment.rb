test_name 'puppet module install (with environment)'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

teardown do
  installed_modules = get_installed_modules_for_hosts hosts
  rm_installed_modules_from_hosts orig_installed_modules, installed_modules
  # TODO make helper take environments into account
  on master, "rm -rf #{master['puppetpath']}/testenv #{master['puppetpath']}/puppet2.conf"
end

step 'Setup'

stub_forge_on(master)

# Configure a non-default environment
on master, "rm -rf #{master['puppetpath']}/testenv"
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

step 'Install a module into a non default environment'
on master, "puppet module install #{module_author}-#{module_name} --config=#{master['puppetpath']}/puppet2.conf --environment=testenv" do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['puppetpath']}/testenv/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['puppetpath']}/testenv/modules
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['puppetpath']}/testenv/modules/#{module_name} ]"
