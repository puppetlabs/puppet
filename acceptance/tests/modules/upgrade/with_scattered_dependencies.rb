test_name "puppet module upgrade (with scattered dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
  on master, "rm -rf #{master['distmoduledir']}/postgresql"
end

on master, puppet("module install pmtacceptance-stdlib --version 0.0.2 --target-dir #{master['sitemoduledir']}")
on master, puppet("module install pmtacceptance-java --version 1.6.0 --target-dir #{master['distmoduledir']} --ignore-dependencies")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.1 --target-dir #{master['distmoduledir']} --ignore-dependencies")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-postgresql (\e[0;36mv0.0.1\e[0m)
    #{master['distmoduledir']}
    └── pmtacceptance-stdlib (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Upgrade a module that has a more recent version published"
on master, puppet("module upgrade pmtacceptance-postgresql --version 0.0.2") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-postgresql' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-postgresql' (\e[0;36mv0.0.1\e[m) in #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-postgresql (\e[0;36mv0.0.1 -> v0.0.2\e[0m)
      ├─┬ pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
      │ └── pmtacceptance-stdlib (\e[0;36mv0.0.2 -> v1.0.0\e[0m) [#{master['sitemoduledir']}]
      └── pmtacceptance-stdlib (\e[0;36mv0.0.2 -> v1.0.0\e[0m) [#{master['sitemoduledir']}]
  OUTPUT
end
