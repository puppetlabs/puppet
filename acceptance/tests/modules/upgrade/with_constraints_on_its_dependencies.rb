test_name "puppet module upgrade (with constraints on its dependencies)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

default_moduledir = get_default_modulepath_for_host(master)

apply_manifest_on master, <<-PP
  file {
    [
      '#{default_moduledir}/unicorns',
    ]: ensure => directory;
    '#{default_moduledir}/unicorns/metadata.json':
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
on master, puppet("module list --modulepath #{default_moduledir}") do
  assert_equal <<-OUTPUT, stdout
#{default_moduledir}
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
on master, puppet("module list --modulepath #{default_moduledir}") do
  assert_equal <<-OUTPUT, stdout
#{default_moduledir}
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlub (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Upgrade a single module, ignoring its dependencies"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0 --ignore-dependencies") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{default_moduledir} ...\e[0m
\e[mNotice: Downloading from https://forgeapi.puppet.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{default_moduledir}
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
