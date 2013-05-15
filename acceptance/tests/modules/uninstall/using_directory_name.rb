test_name "puppet module uninstall (using directory name)"

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
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'apache' ...\e[0m
    Removed 'apache' from #{master['distmoduledir']}
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/apache ]"

step "Try to uninstall the module crakorn"
on master, puppet('module uninstall crakorn'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'crakorn' ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'crakorn'
    STDERR>   Module 'crakorn' is not installed
    STDERR>     You may have meant `puppet module uninstall jimmy-crakorn`\e[0m
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/crakorn ]"
