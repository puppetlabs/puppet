test_name "puppet module upgrade (in a secondary directory)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['sitemoduledir']}/java"
end

on master, puppet("module install pmtacceptance-java --version 1.6.0 --target-dir #{master['sitemoduledir']}")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    #{master['sitemoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Upgrade a module that has a more recent version published"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['sitemoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['sitemoduledir']}
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end
