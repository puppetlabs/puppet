test_name "puppet module install (force ignores dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/php"
  on master, "rm -rf #{master['distmoduledir']}/apache"
  on master, "rm -rf #{master['sitemoduledir']}/php"
  on master, "rm -rf #{master['sitemoduledir']}/apache"
end

step "Try to install an unsatisfiable module"
on master, puppet("module install pmtacceptance-php"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-php' (latest: v0.0.2)
    STDERR>   No version of 'pmtacceptance-php' will satisfy dependencies
    STDERR>     You specified 'pmtacceptance-php' (latest: v0.0.2),
    STDERR>     which depends on 'pmtacceptance-apache' (v0.0.1),
    STDERR>     which depends on 'pmtacceptance-php' (v0.0.1)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/php ]"
on master, "[ ! -d #{master['distmoduledir']}/apache ]"

step "Install an unsatisfiable module with force"
on master, puppet("module install pmtacceptance-php --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-php (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/php ]"
on master, "[ ! -d #{master['distmoduledir']}/apache ]"
