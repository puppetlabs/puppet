test_name "puppet module uninstall (with module installed)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

default_moduledir = get_default_modulepath_for_host(master)

teardown do
  on master, "rm -rf #{default_moduledir}/crakorn"
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
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

on master, "[ -d #{default_moduledir}/crakorn ]"

step "Uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn') do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{default_moduledir}
  OUTPUT
end
on master, "[ ! -d #{default_moduledir}/crakorn ]"
