test_name "puppet module install (with no dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/nginx"
  on master, "rm -rf #{master['sitemoduledir']}/nginx"
end

step "Install a module with no dependencies"
on master, puppet("module install pmtacceptance-nginx") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/nginx ]"
