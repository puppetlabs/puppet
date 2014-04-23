test_name "puppet module upgrade (with constraints on its dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/unicorns"
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlub"
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
          { "name": "pmtacceptance/stdlub", "version_requirement": "0.0.2" }
        ]
      }';
  }
PP
on master, puppet("module install pmtacceptance-stdlub --version 0.0.2")
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_equal <<-OUTPUT, stdout
#{master['distmoduledir']}
├── notpmtacceptance-unicorns (\e[0;36mv0.0.3\e[0m)
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlub (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Try to upgrade a module with constraints on its dependencies that cannot be met"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.1"), :acceptable_exit_codes => [1] do
  assert_match(/No version.* can satisfy all dependencies/, stderr,
        "Unsatisfiable dependency was not displayed")
end

step "Relax constraints"
on master, puppet("module uninstall notpmtacceptance-unicorns")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_equal <<-OUTPUT, stdout
#{master['distmoduledir']}
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlub (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Upgrade a single module, ignoring its dependencies"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0 --ignore-dependencies") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
\e[mNotice: Downloading from https://forgeapi.puppetlabs.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{master['distmoduledir']}
└── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
  OUTPUT
end

step "Attempt to upgrade a module where dependency requires upgrade across major version"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  assert_match(/There are 1 newer versions/, stderr,
    'Number of newer releases was not displayed')

  assert_match(/Dependencies will not be automatically upgraded across major versions/, stderr,
    'Dependency upgrade restriction message was not displayed')

  assert_match(/pmtacceptance-stdlub/, stderr,
    'Potential culprit depdendency was not displayed')
end
