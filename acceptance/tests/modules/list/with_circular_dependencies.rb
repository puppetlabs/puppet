test_name "puppet module list (with circular dependencies)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

default_moduledir = get_default_modulepath_for_host(master)
secondary_moduledir = get_nondefault_modulepath_for_host(master)

skip_test "no secondary moduledir available on master" if secondary_moduledir.empty?

teardown do
  on master, "rm -rf #{default_moduledir}/appleseed"
  on master, "rm -rf #{secondary_moduledir}/crakorn"
end

step "Setup"

apply_manifest_on master, <<-PP
file {
  [
    '#{default_moduledir}/appleseed',
    '#{secondary_moduledir}/crakorn',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '#{secondary_moduledir}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/appleseed", "version_requirement": "1.1.0" }
      ]
    }';
  '#{default_moduledir}/appleseed/metadata.json':
    content => '{
      "name": "jimmy/appleseed",
      "version": "1.1.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crakorn", "version_requirement": "0.4.0" }
      ]
    }';
}
PP
on master, "[ -d #{default_moduledir}/appleseed ]"
on master, "[ -d #{secondary_moduledir}/crakorn ]"

step "List the installed modules"
on master, puppet("module list") do
  assert_match /jimmy-crakorn/, stdout, 'Could not find jimmy crakorn'
  assert_match /jimmy-appleseed/, stdout, 'Could not find jimmy appleseed, but then again... wasnt it johnny appleseed?'
end

step "List the installed modules as a dependency tree"
on master, puppet("module list --tree") do
  assert_match /jimmy-crakorn.*\[#{secondary_moduledir}\]/, stdout, 'Could not find jimmy crakorn'
  assert_match /jimmy-appleseed.*\[#{default_moduledir}\]/, stdout, 'Could not find jimmy appleseed, but then again... wasnt it johnny appleseed?'
end
