test_name "puppet module uninstall (with modulepath)"

teardown do
  on master, "rm -rf #{master['puppetpath']}/modules2"
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{master['puppetpath']}/modules2',
    '#{master['puppetpath']}/modules2/crakorn',
    '#{master['puppetpath']}/modules2/absolute',
  ]: ensure => directory;
  '#{master['puppetpath']}/modules2/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
  '#{master['puppetpath']}/modules2/absolute/metadata.json':
    content => '{
      "name": "jimmy/absolute",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

on master, "[ -d #{master['puppetpath']}/modules2/crakorn ]"
on master, "[ -d #{master['puppetpath']}/modules2/absolute ]"

step "Try to uninstall the module jimmy-crakorn using relative modulepath"
on master, "cd #{master['puppetpath']}/modules2 && puppet module uninstall jimmy-crakorn --modulepath=." do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{master['puppetpath']}/modules2
  OUTPUT
end

on master, "[ ! -d #{master['puppetpath']}/modules2/crakorn ]"

step "Try to uninstall the module jimmy-absolute using an absolute modulepath"
on master, "cd #{master['puppetpath']}/modules2 && puppet module uninstall jimmy-absolute --modulepath=#{master['puppetpath']}/modules2" do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-absolute' ...\e[0m
    Removed 'jimmy-absolute' (\e[0;36mv0.4.0\e[0m) from #{master['puppetpath']}/modules2
  OUTPUT
end
on master, "[ ! -d #{master['puppetpath']}/modules2/absolute ]"
