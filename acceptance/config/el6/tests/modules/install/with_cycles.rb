test_name "puppet module install (with cycles)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "Install a module with cycles"
on master, puppet("module install pmtacceptance-php --version 0.0.1") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └─┬ pmtacceptance-php (\e[0;36mv0.0.1\e[0m)
      └── pmtacceptance-apache (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

on master, puppet('module list') do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-apache (\e[0;36mv0.0.1\e[0m)
    └── pmtacceptance-php (\e[0;36mv0.0.1\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end
