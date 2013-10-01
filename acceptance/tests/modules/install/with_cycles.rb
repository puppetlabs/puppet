test_name "puppet module install (with cycles)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "php"
module_dependencies   = ["apache"]

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

# How does this test differ from a with_version test???
step "Install a module with cycles"
on master, puppet("module install #{module_author}-#{module_name} --version 0.0.1") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
      └── #{module_author}-apache (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

# This isn't going to work
on master, puppet("module list --modulepath #{master['distmoduledir']}") do |res|
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── #{module_author}-apache (\e[0;36mv0.0.1\e[0m)
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
