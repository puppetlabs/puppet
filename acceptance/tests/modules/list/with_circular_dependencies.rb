test_name "puppet module list (with circular dependencies)"

tag 'audit:low',
    'audit:integration',
    'audit:refactor'     # Master is not required for this test.
                         # Refactor to use agent.

teardown do
  on master, "rm -rf #{master['distmoduledir']}/appleseed"
  on master, "rm -rf #{master['sitemoduledir']}/crakorn"
end

step "Setup"

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/appleseed',
    '#{master['sitemoduledir']}/crakorn',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '#{master['sitemoduledir']}/crakorn/metadata.json':
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
}
PP
on master, "[ -d #{master['distmoduledir']}/appleseed ]"
on master, "[ -d #{master['sitemoduledir']}/crakorn ]"

step "List the installed modules"
on master, puppet("module list") do
  assert_match /jimmy-crakorn/, stdout, 'Could not find jimmy crakorn'
  assert_match /jimmy-appleseed/, stdout, 'Could not find jimmy appleseed, but then again... wasnt it johnny appleseed?'
end

step "List the installed modules as a dependency tree"
on master, puppet("module list --tree") do
  assert_match /jimmy-crakorn.*\[#{master['sitemoduledir']}\]/, stdout, 'Could not find jimmy crakorn'
  assert_match /jimmy-appleseed.*\[#{master['distmoduledir']}\]/, stdout, 'Could not find jimmy appleseed, but then again... wasnt it johnny appleseed?'
end
