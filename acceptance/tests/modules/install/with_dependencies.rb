test_name "puppet module install (with dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
end

step "Install a module with dependencies"
on master, puppet("module install pmtacceptance-java") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-java (\e[0;36mv1.7.1\e[0m)
      └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/java ]"
on master, "[ -d #{master['distmoduledir']}/stdlib ]"
