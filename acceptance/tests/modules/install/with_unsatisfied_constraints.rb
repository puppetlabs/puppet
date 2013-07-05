test_name "puppet module install (with unsatisfied constraints)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "git"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

teardown do
  installed_modules = get_installed_modules_for_hosts hosts
  rm_installed_modules_from_hosts orig_installed_modules, installed_modules
end

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/crakorn',
  ]: ensure => directory;
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
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-#{module_name}' (latest: v0.0.1)
    STDERR>   No version of '#{module_author}-stdlib' will satisfy dependencies
    STDERR>     'jimmy-crakorn' (v0.0.1) requires '#{module_author}-stdlib' (v1.x)
    STDERR>     '#{module_author}-#{module_name}' (v0.0.1) requires '#{module_author}-stdlib' (>= 2.0.0)
    STDERR>     Use `puppet module install --ignore-dependencies` to install only this module\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/#{module_name} ]"

step "Install the module with an unsatisfiable dependency"
on master, puppet("module install #{module_author}-#{module_name} --ignore-dependencies") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"

step "Try to install a specific version of the unsatisfiable dependency"
on master, puppet("module install #{module_author}-stdlib --version 1.x"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-stdlib' (v1.x)
    STDERR>   No version of '#{module_author}-stdlib' will satisfy dependencies
    STDERR>     You specified '#{module_author}-stdlib' (v1.x)
    STDERR>     'jimmy-crakorn' (v0.0.1) requires '#{module_author}-stdlib' (v1.x)
    STDERR>     '#{module_author}-#{module_name}' (v0.0.1) requires '#{module_author}-stdlib' (>= 2.0.0)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/stdlib ]"

step "Try to install any version of the unsatisfiable dependency"
on master, puppet("module install #{module_author}-stdlib"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-stdlib' (best: v1.0.0)
    STDERR>   No version of '#{module_author}-stdlib' will satisfy dependencies
    STDERR>     You specified '#{module_author}-stdlib' (best: v1.0.0)
    STDERR>     'jimmy-crakorn' (v0.0.1) requires '#{module_author}-stdlib' (v1.x)
    STDERR>     '#{module_author}-#{module_name}' (v0.0.1) requires '#{module_author}-stdlib' (>= 2.0.0)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/stdlib ]"

step "Install the unsatisfiable dependency with --force"
on master, puppet("module install #{module_author}-stdlib --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/stdlib ]"
