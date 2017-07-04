test_name "puppet module upgrade (that was installed twice)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

prod_env_modulepath = "#{environmentpath}/production/modules"

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

on master, puppet("module install pmtacceptance-java --version 1.7.0 --modulepath #{prod_env_modulepath}")
on master, puppet("module install pmtacceptance-java --version 1.6.0 --modulepath #{master['distmoduledir']}")

on master, puppet("module list") do |result|
  pattern = Regexp.new([
    "#{prod_env_modulepath}",
    "├── pmtacceptance-java \\(.*v1.7.0.*\\)",
    "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)",
    "#{master['distmoduledir']}",
    "├── pmtacceptance-java \\(.*v1.6.0\e.*\\)",
    "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)",
  ].join("\n"))
  assert_match(pattern, result.output)
end

step "Try to upgrade a module that exists multiple locations in the module path"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do |result|
  pattern = Regexp.new([
    ".*Notice: Preparing to upgrade 'pmtacceptance-java' .*",
    ".*Error: Could not upgrade module 'pmtacceptance-java'",
    "  Module 'pmtacceptance-java' appears multiple places in the module path",
    "    'pmtacceptance-java' \\(v1.7.0\\) was found in #{prod_env_modulepath}",
    "    'pmtacceptance-java' \\(v1.6.0\\) was found in #{master['distmoduledir']}",
    "    Use the `--modulepath` option to limit the search to specific directories",
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end

step "Upgrade a module that exists multiple locations by restricting the --modulepath"
on master, puppet("module upgrade pmtacceptance-java --modulepath #{master['distmoduledir']}") do
  pattern = Regexp.new([
    ".*Notice: Preparing to upgrade 'pmtacceptance-java' .*",
    ".*Notice: Found 'pmtacceptance-java' \\(.*v1.6.0.*\\) in #{master['distmoduledir']} .*",
    ".*Notice: Downloading from https://forgeapi.puppet(labs)?.com .*",
    ".*Notice: Upgrading -- do not interrupt .*",
    "#{master['distmoduledir']}",
    "└── pmtacceptance-java \\(.*v1.6.0 -> v1.7.1.*\\)",
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
