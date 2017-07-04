test_name "puppet module uninstall (with active dependency)"

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/crakorn',
    '#{master['distmoduledir']}/appleseed',
  ]: ensure => directory;
  '#{master['distmoduledir']}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
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
}
PP

teardown do
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
  on master, "rm -rf #{master['distmoduledir']}/appleseed"
end

on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['distmoduledir']}/appleseed ]"

step "Try to uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn'), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to uninstall 'jimmy-crakorn' .*},
    %Q{.*Error: Could not uninstall module 'jimmy-crakorn'},
    %Q{  Other installed modules have dependencies on 'jimmy-crakorn' \\(v0.4.0\\)},
    %Q{    'jimmy/appleseed' \\(v1.1.0\\) requires 'jimmy-crakorn' \\(v0.4.0\\)},
    %Q{    Use `puppet module uninstall --force` to uninstall this module anyway.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['distmoduledir']}/appleseed ]"

step "Try to uninstall the module jimmy-crakorn with a version range"
on master, puppet('module uninstall jimmy-crakorn --version 0.x'), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to uninstall 'jimmy-crakorn' \\(.*v0.x.*\\) .*},
    %Q{.*Error: Could not uninstall module 'jimmy-crakorn' \\(v0.x\\)},
    %Q{  Other installed modules have dependencies on 'jimmy-crakorn' \\(v0.4.0\\)},
    %Q{    'jimmy/appleseed' \\(v1.1.0\\) requires 'jimmy-crakorn' \\(v0.4.0\\)},
    %Q{    Use `puppet module uninstall --force` to uninstall this module anyway.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['distmoduledir']}/appleseed ]"

step "Uninstall the module jimmy-crakorn forcefully"
on master, puppet('module uninstall jimmy-crakorn --force') do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{master['distmoduledir']}
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['distmoduledir']}/appleseed ]"
