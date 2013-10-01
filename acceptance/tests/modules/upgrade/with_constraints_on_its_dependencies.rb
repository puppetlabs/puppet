test_name "puppet module upgrade (with constraints on its dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/unicorns"
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
end

apply_manifest_on master, <<-PP
  file {
    [
      '#{master['distmoduledir']}/unicorns',
    ]: ensure => directory;
    '#{master['distmoduledir']}/unicorns/metadata.json':
      content => '{
        "name": "notpmtacceptance/unicorns",
        "version": "0.0.3",
        "source": "",
        "author": "notpmtacceptance",
        "license": "MIT",
        "dependencies": [
          { "name": "pmtacceptance/stdlib", "version_requirement": "0.0.2" }
        ]
      }';
  }
PP
on master, puppet("module install pmtacceptance-stdlib --version 0.0.2")
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── notpmtacceptance-unicorns (\e[0;36mv0.0.3\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Try to upgrade a module with constraints on its dependencies that cannot be met"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    STDOUT> \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.6.0 -> latest: v1.7.1)
    STDERR>   No version of 'pmtacceptance-stdlib' will satisfy dependencies
    STDERR>     'notpmtacceptance-unicorns' (v0.0.3) requires 'pmtacceptance-stdlib' (v0.0.2)
    STDERR>     'pmtacceptance-java' (v1.7.1) requires 'pmtacceptance-stdlib' (v1.0.0)
    STDERR>     Use `puppet module upgrade --ignore-dependencies` to upgrade only this module\e[0m
  OUTPUT
end

step "Relax constraints"
on master, puppet("module uninstall notpmtacceptance-unicorns")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Upgrade a single module, ignoring its dependencies"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0 --ignore-dependencies") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
  OUTPUT
end

step "Upgrade a module with constraints on its dependencies that can be met"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.7.0\e[m) in #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-java (\e[0;36mv1.7.0 -> v1.7.1\e[0m)
      └── pmtacceptance-stdlib (\e[0;36mv0.0.2 -> v1.0.0\e[0m)
  OUTPUT
end
