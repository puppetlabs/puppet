test_name "puppet module list (with invalid dependencies)"
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
    '#{default_moduledir}/appleseed',
    '#{default_moduledir}/crakorn',
    '#{default_moduledir}/thelock',
    '#{secondary_moduledir}/crick',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
   '#{default_moduledir}/crakorn/metadata.json':
     content => '{
       "name": "jimmy/crakorn",
       "version": "0.3.0",
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
        { "name": "jimmy/crakorn", "version_requirement": "0.x" }
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

on master, "[ -d #{default_moduledir}/appleseed ]"
on master, "[ -d #{default_moduledir}/crakorn ]"
on master, "[ -d #{default_moduledir}/thelock ]"
on master, "[ -d #{secondary_moduledir}/crick ]"

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

  assert_match /jimmy-crakorn.*\[#{default_moduledir}\].*invalid/, res.stdout
end
