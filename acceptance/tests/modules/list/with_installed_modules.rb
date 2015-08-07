test_name "puppet module list (with installed modules)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

default_moduledir = get_default_modulepath_for_host(master)
secondary_moduledir = get_nondefault_modulepath_for_host(master)

skip_test "no secondary moduledir available on master" if secondary_moduledir.empty?

teardown do
  on master, "rm -rf #{default_moduledir}/thelock"
  on master, "rm -rf #{default_moduledir}/appleseed"
  on master, "rm -rf #{default_moduledir}/crakorn"
  on master, "rm -rf #{secondary_moduledir}/crick"
end

step "Setup"

apply_manifest_on master, <<-PP
file {
  [
    '#{default_moduledir}/crakorn',
    '#{default_moduledir}/appleseed',
    '#{default_moduledir}/thelock',
    '#{secondary_moduledir}/crick',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '#{default_moduledir}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
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
  '#{default_moduledir}/thelock/metadata.json':
    content => '{
      "name": "jimmy/thelock",
      "version": "1.0.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/appleseed", "version_requirement": "1.x" }
      ]
    }';
  '#{secondary_moduledir}/crick/metadata.json':
    content => '{
      "name": "jimmy/crick",
      "version": "1.0.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crakorn", "version_requirement": "0.4.x" }
      ]
    }';
}
PP

on master, "[ -d #{default_moduledir}/crakorn ]"
on master, "[ -d #{default_moduledir}/appleseed ]"
on master, "[ -d #{default_moduledir}/thelock ]"
on master, "[ -d #{secondary_moduledir}/crick ]"

step "List the installed modules"
on master, puppet("module list --modulepath #{default_moduledir}") do
  assert_equal <<-STDOUT, stdout
#{default_moduledir}
├── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)
├── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)
└── jimmy-thelock (\e[0;36mv1.0.0\e[0m)
STDOUT
end

on master, puppet("module list --modulepath #{secondary_moduledir}") do |res|
  assert_match( /jimmy-crick/,
                res.stdout,
                'Did not find module jimmy-crick in module site path')
end

step "List the installed modules as a dependency tree"
on master, puppet("module list --tree --modulepath #{default_moduledir}") do
  assert_equal <<-STDOUT, stdout
#{default_moduledir}
└─┬ jimmy-thelock (\e[0;36mv1.0.0\e[0m)
  └─┬ jimmy-appleseed (\e[0;36mv1.1.0\e[0m)
    └── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)
STDOUT
end

on master, puppet("module list --tree --modulepath #{secondary_moduledir}") do |res|
  assert_match( /jimmy-crakorn/,
                res.stdout,
                'Did not find module jimmy-crakorn in module site path')

  assert_match( /jimmy-crick/,
                res.stdout,
                'Did not find module jimmy-crick in module site path')
end
