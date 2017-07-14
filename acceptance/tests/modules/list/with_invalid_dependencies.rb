test_name "puppet module list (with invalid dependencies)"

tag 'audit:low',
    'audit:unit'

teardown do
  on master, "rm -rf #{master['distmoduledir']}/thelock"
  on master, "rm -rf #{master['distmoduledir']}/appleseed"
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
  on master, "rm -rf #{master['sitemoduledir']}/crick"
end

step "Setup"

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/appleseed',
    '#{master['distmoduledir']}/crakorn',
    '#{master['distmoduledir']}/thelock',
    '#{master['sitemoduledir']}/crick',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
   '#{master['distmoduledir']}/crakorn/metadata.json':
     content => '{
       "name": "jimmy/crakorn",
       "version": "0.3.0",
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
        { "name": "jimmy/crakorn", "version_requirement": "0.x" }
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

on master, "[ -d #{master['distmoduledir']}/appleseed ]"
on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['distmoduledir']}/thelock ]"
on master, "[ -d #{master['sitemoduledir']}/crick ]"

step "List the installed modules"
on master, puppet("module list") do |res|
  pattern = Regexp.new([
    %Q{.*Warning: Module 'jimmy-crakorn' \\(v0.3.0\\) fails to meet some dependencies:},
    %Q{  'jimmy-crick' \\(v1.0.1\\) requires 'jimmy-crakorn' \\(v0.4.x\\).*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)

  assert_match /jimmy-crakorn.*invalid/, res.stdout, 'Did not find module jimmy-crick in module site path'
end

step "List the installed modules as a dependency tree"
on master, puppet("module list --tree") do |res|

  pattern = Regexp.new([
    %Q{.*Warning: Module 'jimmy-crakorn' \\(v0.3.0\\) fails to meet some dependencies:},
    %Q{  'jimmy-crick' \\(v1.0.1\\) requires 'jimmy-crakorn' \\(v0.4.x\\).*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)

  assert_match /jimmy-crakorn.*\[#{master['distmoduledir']}\].*invalid/, res.stdout
end
