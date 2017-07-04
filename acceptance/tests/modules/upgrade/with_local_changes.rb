test_name "puppet module upgrade (with local changes)"
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
apply_manifest_on master, <<-PP
  file {
    '#{default_moduledir}/java/README': content => "I CHANGE MY READMES";
    '#{default_moduledir}/java/NEWFILE': content => "I don't exist.'";
  }
PP

step "Try to upgrade a module with local changes"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to upgrade 'pmtacceptance-java' ....*},
    %Q{.*Notice: Found 'pmtacceptance-java' \\(.*v1.6.0.*\\) in #{default_moduledir} ....*},
    %Q{.*Error: Could not upgrade module 'pmtacceptance-java' \\(v1.6.0 -> latest\\)},
    %Q{  Installed module has had changes made locally},
    %Q{    Use `puppet module upgrade --ignore-changes` to upgrade this module anyway.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
on master, %{[[ "$(cat #{default_moduledir}/java/README)" == "I CHANGE MY READMES" ]]}
on master, "[ -f #{default_moduledir}/java/NEWFILE ]"

step "Upgrade a module with local changes with --force"
on master, puppet("module upgrade pmtacceptance-java --force") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{default_moduledir} ...\e[0m
\e[mNotice: Downloading from https://forgeapi.puppet.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{default_moduledir}
└── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end
on master, %{[[ "$(cat #{default_moduledir}/java/README)" != "I CHANGE MY READMES" ]]}
on master, "[ ! -f #{default_moduledir}/java/NEWFILE ]"
