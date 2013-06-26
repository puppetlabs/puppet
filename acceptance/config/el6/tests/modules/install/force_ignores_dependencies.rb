test_name "puppet module install (force ignores dependencies)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "Try to install an unsatisfiable module"
on master, puppet("module install pmtacceptance-php"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-php' (latest: v0.0.2)
    STDERR>   No version of 'pmtacceptance-php' will satisfy dependencies
    STDERR>     You specified 'pmtacceptance-php' (latest: v0.0.2),
    STDERR>     which depends on 'pmtacceptance-apache' (v0.0.1),
    STDERR>     which depends on 'pmtacceptance-php' (v0.0.1)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/php ]'
on master, '[ ! -d /etc/puppet/modules/apache ]'

step "Install an unsatisfiable module with force"
on master, puppet("module install pmtacceptance-php --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-php (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/php ]'
on master, '[ ! -d /etc/puppet/modules/apache ]'
