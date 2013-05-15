test_name "puppet module install (with unsatisfied constraints)"

step 'Setup'

stub_forge_on(master)
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"

teardown do
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
  on master, "rm -rf #{master['distmoduledir']}/git"
  on master, "rm -rf #{master['sitemoduledir']}/crakorn"
  on master, "rm -rf #{master['sitemoduledir']}/git"
end

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
        { "name": "pmtacceptance/stdlib", "version_requirement": "1.x" }
      ]
    }';
}
PP

step "Try to install a module that has an unsatisfiable dependency"
on master, puppet("module install pmtacceptance-git"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-git' (latest: v0.0.1)
    STDERR>   No version of 'pmtacceptance-stdlib' will satisfy dependencies
    STDERR>     'jimmy-crakorn' (v0.0.1) requires 'pmtacceptance-stdlib' (v1.x)
    STDERR>     'pmtacceptance-git' (v0.0.1) requires 'pmtacceptance-stdlib' (>= 2.0.0)
    STDERR>     Use `puppet module install --ignore-dependencies` to install only this module\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/git ]"

step "Install the module with an unsatisfiable dependency"
on master, puppet("module install pmtacceptance-git --ignore-dependencies") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-git (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/git ]"

step "Try to install a specific version of the unsatisfiable dependency"
on master, puppet("module install pmtacceptance-stdlib --version 1.x"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-stdlib' (v1.x)
    STDERR>   No version of 'pmtacceptance-stdlib' will satisfy dependencies
    STDERR>     You specified 'pmtacceptance-stdlib' (v1.x)
    STDERR>     'jimmy-crakorn' (v0.0.1) requires 'pmtacceptance-stdlib' (v1.x)
    STDERR>     'pmtacceptance-git' (v0.0.1) requires 'pmtacceptance-stdlib' (>= 2.0.0)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/stdlib ]"

step "Try to install any version of the unsatisfiable dependency"
on master, puppet("module install pmtacceptance-stdlib"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-stdlib' (best: v1.0.0)
    STDERR>   No version of 'pmtacceptance-stdlib' will satisfy dependencies
    STDERR>     You specified 'pmtacceptance-stdlib' (best: v1.0.0)
    STDERR>     'jimmy-crakorn' (v0.0.1) requires 'pmtacceptance-stdlib' (v1.x)
    STDERR>     'pmtacceptance-git' (v0.0.1) requires 'pmtacceptance-stdlib' (>= 2.0.0)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/stdlib ]"

step "Install the unsatisfiable dependency with --force"
on master, puppet("module install pmtacceptance-stdlib --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/stdlib ]"
