test_name "puppet module install (with cycles)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/php"
  on master, "rm -rf #{master['distmoduledir']}/apache"
  on master, "rm -rf #{master['sitemoduledir']}/php"
  on master, "rm -rf #{master['sitemoduledir']}/apache"
end

step "Install a module with cycles"
on master, puppet("module install pmtacceptance-php --version 0.0.1") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ pmtacceptance-php (\e[0;36mv0.0.1\e[0m)
      └── pmtacceptance-apache (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

# This isn't going to work
on master, puppet("module list --modulepath #{master['distmoduledir']}") do |res|
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-apache (\e[0;36mv0.0.1\e[0m)
    └── pmtacceptance-php (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
