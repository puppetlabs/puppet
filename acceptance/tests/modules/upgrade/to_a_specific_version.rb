test_name "puppet module upgrade (to a specific version)"
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

on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{default_moduledir}") do
  assert_equal <<-OUTPUT, stdout
#{default_moduledir}
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlub (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Upgrade a module to a specific (greater) version"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{default_moduledir} ...\e[0m
\e[mNotice: Downloading from https://forgeapi.puppet.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{default_moduledir}
└── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
  OUTPUT
end
