test_name "puppet module upgrade (introducing new dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/postgresql"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
  on master, "rm -rf #{master['distmoduledir']}/geordi"
end

on master, puppet("module install pmtacceptance-stdlib --version 1.0.0")
on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.2")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.7.0\e[0m)
    ├── pmtacceptance-postgresql (\e[0;36mv0.0.2\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Upgrade a module to a version that introduces new dependencies"
on master, puppet("module upgrade pmtacceptance-postgresql") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-postgresql' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-postgresql' (\e[0;36mv0.0.2\e[m) in #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-postgresql (\e[0;36mv0.0.2 -> v1.0.0\e[0m)
      └── pmtacceptance-geordi (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
