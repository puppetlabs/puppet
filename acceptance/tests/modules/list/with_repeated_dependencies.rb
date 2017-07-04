test_name "puppet module list (with repeated dependencies)"

tag 'audit:low',
    'audit:unit'

teardown do
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
  on master, "rm -rf #{master['distmoduledir']}/steward"
  on master, "rm -rf #{master['distmoduledir']}/appleseed"
  on master, "rm -rf #{master['distmoduledir']}/thelock"
  on master, "rm -rf #{master['sitemoduledir']}/crick"
end

step "Setup"

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/crakorn',
    '#{master['distmoduledir']}/steward',
    '#{master['distmoduledir']}/appleseed',
    '#{master['distmoduledir']}/thelock',
    '#{master['sitemoduledir']}/crick',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '#{master['distmoduledir']}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/steward", "version_requirement": ">= 0.0.0" }
      ]
    }';
  '#{master['distmoduledir']}/steward/metadata.json':
    content => '{
      "name": "jimmy/steward",
      "version": "0.9.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
  '#{master['distmoduledir']}/appleseed/metadata.json':
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
  '#{master['distmoduledir']}/thelock/metadata.json':
    content => '{
      "name": "jimmy/thelock",
      "version": "1.0.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crakorn", "version_requirement": ">= 0.0.0" },
        { "name": "jimmy/appleseed", "version_requirement": "1.x" }
      ]
    }';
  '#{master['sitemoduledir']}/crick/metadata.json':
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

on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['distmoduledir']}/steward ]"
on master, "[ -d #{master['distmoduledir']}/appleseed ]"
on master, "[ -d #{master['distmoduledir']}/thelock ]"
on master, "[ -d #{master['sitemoduledir']}/crick ]"

step "List the installed modules"
on master, puppet('module list') # assertion is exit code 0

step "List the installed modules as a dependency tree"
on master, puppet("module list --tree --modulepath #{master['distmoduledir']}") do
  assert_equal <<-STDOUT, stdout
#{master['distmoduledir']}
└─┬ jimmy-thelock (\e[0;36mv1.0.0\e[0m)
  ├─┬ jimmy-crakorn (\e[0;36mv0.4.0\e[0m)
  │ └── jimmy-steward (\e[0;36mv0.9.0\e[0m)
  └── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)
STDOUT
end

on master, puppet("module list --tree") do
  assert_match( /jimmy-crakorn.*\[#{master['distmoduledir']}\]/,
                stdout,
                'Did not find cross modulepath reference to jimmy-crakorn' )
  assert_match( /jimmy-steward.*\[#{master['distmoduledir']}\]/,
                stdout,
                'Did not find cross modulepath reference to jimmy-steward' )
end
