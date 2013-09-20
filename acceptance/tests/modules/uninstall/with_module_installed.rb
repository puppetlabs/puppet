test_name "puppet module uninstall (with module installed)"

teardown do
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
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

on master, "[ -d #{master['distmoduledir']}/crakorn ]"

step "Uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{master['distmoduledir']}
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/crakorn ]"
