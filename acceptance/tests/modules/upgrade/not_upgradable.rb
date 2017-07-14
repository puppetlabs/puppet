test_name "puppet module upgrade (not upgradable)"
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

on master, "mkdir -p #{default_moduledir}"
apply_manifest_on master, <<-PP
  file {
    [
      '#{default_moduledir}/nginx',
      '#{default_moduledir}/unicorns',
    ]: ensure => directory;
    '#{default_moduledir}/unicorns/metadata.json':
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
on master, puppet("module list --modulepath #{default_moduledir}") do
  assert_equal <<-OUTPUT, stdout
#{default_moduledir}
├── nginx (\e[0;36m???\e[0m)
├── notpmtacceptance-unicorns (\e[0;36mv0.0.3\e[0m)
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlub (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Try to upgrade a module that is not installed"
on master, puppet("module upgrade pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to upgrade 'pmtacceptance-nginx' .*},
    %Q{.*Error: Could not upgrade module 'pmtacceptance-nginx'},
    %Q{  Module 'pmtacceptance-nginx' is not installed},
    %Q{    Use `puppet module install` to install this module.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end

# TODO: Determine the appropriate response for this test.
# step "Try to upgrade a local module"
# on master, puppet("module upgrade nginx"), :acceptable_exit_codes => [1] do
#   pattern = Regexp.new([
#     %Q{.*Notice: Preparing to upgrade 'nginx' .*},
#     %Q{.*Notice: Found 'nginx' \\(.*\\?\\?\\?.*\\) in #{default_moduledir} .*},
#     %Q{.*Notice: Downloading from https://forgeapi.puppet.com .*},
#     %Q{.*Error: Could not upgrade module 'nginx' \\(\\?\\?\\? -> latest\\)},
#     %Q{  Module 'nginx' does not exist on https://forgeapi.puppet.com.*},
#   ].join("\n"), Regexp::MULTILINE)
#   assert_match(pattern, result.output)
# end

step "Try to upgrade a module that doesn't exist in module_repository"
on master, puppet("module upgrade notpmtacceptance-unicorns"), :acceptable_exit_codes => [1] do
  assert_match(/could not upgrade 'notpmtacceptance-unicorns'/i, stderr,
    'Could not upgrade error not shown')

  assert_match(/no releases are available from/i, stderr,
    'Upgrade failure reason not shown')
end

step "Try to upgrade an installed module to a version that doesn't exist in module_repository"
on master, puppet("module upgrade pmtacceptance-java --version 2.0.0"), :acceptable_exit_codes => [1] do
  assert_match(/could not upgrade 'pmtacceptance-java'/i, stderr,
    'Could not upgrade error not shown')

  assert_match(/no releases matching '2.0.0' are available from/i, stderr,
    'Upgrade failure reason not shown')
end
