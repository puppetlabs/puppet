test_name "puppet module uninstall (with module installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/crakorn',
    '#{master['sitemoduledir']}/crakorn',
    '#{master['sitemoduledir']}/appleseed',
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
  '#{master['sitemoduledir']}/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.5.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
  '#{master['sitemoduledir']}/appleseed/metadata.json':
    content => '{
      "name": "jimmy/appleseed",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

teardown do
  on master, "rm -rf #{master['distmoduledir']}/crakorn"
  on master, "rm -rf #{master['sitemoduledir']}/crakorn"
  on master, "rm -rf #{master['sitemoduledir']}/appleseed"
end

on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ -d #{master['sitemoduledir']}/crakorn ]"

step "Uninstall jimmy-crakorn version 0.5.x"
on master, puppet('module uninstall jimmy-crakorn --version 0.5.x') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' (\e[0;36mv0.5.x\e[m) ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.5.1\e[0m) from #{master['sitemoduledir']}
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/crakorn ]"
on master, "[ ! -d #{master['sitemoduledir']}/crakorn ]"

step "Try to uninstall jimmy-crakorn v0.4.0 with `--version 0.5.x`"
on master, puppet('module uninstall jimmy-crakorn --version 0.5.x'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'jimmy-crakorn' (\e[0;36mv0.5.x\e[m) ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'jimmy-crakorn' (v0.5.x)
    STDERR>   No installed version of 'jimmy-crakorn' matches (v0.5.x)
    STDERR>     'jimmy-crakorn' (v0.4.0) is installed in #{master['distmoduledir']}\e[0m
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/crakorn ]"

step "Try to uninstall jimmy-appleseed v0.4.0 with `--version >9.9.9`"
on master, puppet('module uninstall jimmy-appleseed --version ">9.9.9"'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'jimmy-appleseed' (\e[0;36m>9.9.9\e[m) ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'jimmy-appleseed' (>9.9.9)
    STDERR>   No installed version of 'jimmy-appleseed' matches (>9.9.9)
    STDERR>     'jimmy-appleseed' (v0.4.0) is installed in #{master['sitemoduledir']}\e[0m
  OUTPUT
end
on master, "[ -d #{master['sitemoduledir']}/appleseed ]"

step "Uninstall jimmy-appleseed v0.4.0 with `--version >0.0.0`"
on master, puppet('module uninstall jimmy-appleseed --version ">0.0.0"') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-appleseed' (\e[0;36m>0.0.0\e[m) ...\e[0m
    Removed 'jimmy-appleseed' (\e[0;36mv0.4.0\e[0m) from #{master['sitemoduledir']}
  OUTPUT
end
on master, "[ ! -d #{master['sitemoduledir']}/appleseed ]"
