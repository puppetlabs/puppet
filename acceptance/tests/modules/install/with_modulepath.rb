# encoding: UTF-8

test_name "puppet module install (with modulepath)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

expected_output = <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['puppetpath']}/modules2 ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['puppetpath']}/modules2
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
OUTPUT

orig_installed_modules = get_installed_modules_for_hosts hosts

teardown do
  installed_modules = get_installed_modules_for_hosts hosts
  rm_installed_modules_from_hosts orig_installed_modules, installed_modules
  # TODO: make helper take modulepath
  on master, "rm -rf #{master['puppetpath']}/modules2"
end

step 'Setup'

stub_forge_on(master)

on master, "mkdir -p #{master['puppetpath']}/modules2"

step "Install a module with relative modulepath"
on master, "cd #{master['puppetpath']}/modules2 && puppet module install #{module_author}-#{module_name} --modulepath=." do
  assert_output expected_output
end
on master, "[ -d #{master['puppetpath']}/modules2/#{module_name} ]"

step "Install a module with absolute modulepath"
on master, "test -d #{master['puppetpath']}/modules2/#{module_name} && rm -rf #{master['puppetpath']}/modules2/#{module_name}"
on master, puppet("module install #{module_author}-#{module_name} --modulepath=#{master['puppetpath']}/modules2") do
  assert_output expected_output
end
on master, "[ -d #{master['puppetpath']}/modules2/#{module_name} ]"
