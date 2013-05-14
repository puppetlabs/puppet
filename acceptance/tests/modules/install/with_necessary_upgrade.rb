test_name "puppet module install (with necessary dependency upgrade)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
end

step "Install an older module version"
on master, puppet("module install pmtacceptance-java --version 1.6.0") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
      └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

on master, puppet("module list --tree --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    └─┬ pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
      └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end


step "Install a module that requires the older module dependency be upgraded"
on master, puppet("module install pmtacceptance-apollo") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-apollo (\e[0;36mv0.0.1\e[0m)
      └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end

on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-apollo (\e[0;36mv0.0.1\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.7.1\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
