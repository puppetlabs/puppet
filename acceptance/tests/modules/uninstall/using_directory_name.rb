test_name "puppet module uninstall (using directory name)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

default_moduledir = get_default_modulepath_for_host(master)

teardown do
  on master, "rm -rf #{default_moduledir}/apache"
  on master, "rm -rf #{default_moduledir}/crakorn"
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{default_moduledir}/apache',
    '#{default_moduledir}/crakorn',
  ]: ensure => directory;
  '#{default_moduledir}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

on master, "[ -d #{default_moduledir}/apache ]"
on master, "[ -d #{default_moduledir}/crakorn ]"

step "Try to uninstall the module apache"
on master, puppet('module uninstall apache') do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'apache' ...\e[0m
Removed 'apache' from #{default_moduledir}
  OUTPUT
end
on master, "[ ! -d #{default_moduledir}/apache ]"

step "Try to uninstall the module crakorn"
on master, puppet('module uninstall crakorn'), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to uninstall 'crakorn' ....*},
    %Q{.*Error: Could not uninstall module 'crakorn'},
    %Q{  Module 'crakorn' is not installed},
    %Q{    You may have meant `puppet module uninstall jimmy-crakorn`.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
on master, "[ -d #{default_moduledir}/crakorn ]"
