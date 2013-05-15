test_name "puppet module upgrade (not upgradable)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/unicorns"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
  on master, "rm -rf #{master['distmoduledir']}/nginx"
end

on master, "mkdir -p #{master['distmoduledir']}"
apply_manifest_on master, <<-PP
  file {
    [
      '#{master['distmoduledir']}/nginx',
      '#{master['distmoduledir']}/unicorns',
    ]: ensure => directory;
    '#{master['distmoduledir']}/unicorns/metadata.json':
      content => '{
        "name": "notpmtacceptance/unicorns",
        "version": "0.0.3",
        "source": "",
        "author": "notpmtacceptance",
        "license": "MIT",
        "dependencies": []
      }';
  }
PP

on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── nginx (\e[0;36m???\e[0m)
    ├── notpmtacceptance-unicorns (\e[0;36mv0.0.3\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Try to upgrade a module that is not installed"
on master, puppet("module upgrade pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'pmtacceptance-nginx' ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-nginx'
    STDERR>   Module 'pmtacceptance-nginx' is not installed
    STDERR>     Use `puppet module install` to install this module\e[0m
  OUTPUT
end

step "Try to upgrade a local module"
on master, puppet("module upgrade nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'nginx' ...\e[0m
    STDOUT> \e[mNotice: Found 'nginx' (\e[0;36m???\e[m) in #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'nginx' (??? -> latest)
    STDERR>   Module 'nginx' does not exist on https://forge.puppetlabs.com\e[0m
  OUTPUT
end

step "Try to upgrade a module that doesn't exist"
on master, puppet("module upgrade notpmtacceptance-unicorns"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'notpmtacceptance-unicorns' ...\e[0m
    STDOUT> \e[mNotice: Found 'notpmtacceptance-unicorns' (\e[0;36mv0.0.3\e[m) in #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'notpmtacceptance-unicorns' (v0.0.3 -> latest)
    STDERR>   Module 'notpmtacceptance-unicorns' does not exist on https://forge.puppetlabs.com\e[0m
  OUTPUT
end

step "Try to upgrade an installed module to a version that doesn't exist"
on master, puppet("module upgrade pmtacceptance-java --version 2.0.0"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    STDOUT> \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.6.0 -> v2.0.0)
    STDERR>   No version matching '2.0.0' exists on https://forge.puppetlabs.com\e[0m
  OUTPUT
end
