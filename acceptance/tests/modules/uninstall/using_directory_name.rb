test_name "puppet module uninstall (using directory name)"

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

teardown do
  on master, "rm -rf #{master['distmoduledir']}/apache"
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/apache',
    '#{master['distmoduledir']}/crakorn',
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
}
PP

on master, "[ -d #{master['distmoduledir']}/apache ]"
on master, "[ -d #{master['distmoduledir']}/crakorn ]"

step "Try to uninstall the module apache"
on master, puppet('module uninstall apache') do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'apache' ...\e[0m
Removed 'apache' from #{master['distmoduledir']}
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/apache ]"

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
on master, "[ -d #{master['distmoduledir']}/crakorn ]"
