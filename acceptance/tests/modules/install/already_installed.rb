test_name "puppet module install (already installed)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/nginx"
  on master, "rm -rf #{master['distmoduledir']}/nginx"
end

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/nginx',
  ]: ensure => directory;
  '#{master['distmoduledir']}/nginx/metadata.json':
    content => '{
      "name": "pmtacceptance/nginx",
      "version": "0.0.1",
      "source": "",
      "author": "pmtacceptance",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

step "Try to install a module that is already installed"
on master, puppet("module install pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (latest)
    STDERR>   Module 'pmtacceptance-nginx' (v0.0.1) is already installed
    STDERR>     Use `puppet module upgrade` to install a different version
    STDERR>     Use `puppet module install --force` to re-install only this module\e[0m
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/nginx ]"

step "Try to install a specific version of a module that is already installed"
on master, puppet("module install pmtacceptance-nginx --version 1.x"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (v1.x)
    STDERR>   Module 'pmtacceptance-nginx' (v0.0.1) is already installed
    STDERR>     Use `puppet module upgrade` to install a different version
    STDERR>     Use `puppet module install --force` to re-install only this module\e[0m
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/nginx ]"

step "Install a module that is already installed (with --force)"
on master, puppet("module install pmtacceptance-nginx --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/nginx ]"
