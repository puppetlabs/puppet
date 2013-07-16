test_name "puppet module install (with necessary dependency upgrade)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "Install an older module version"
on master, puppet("module install pmtacceptance-java --version 1.6.0") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └─┬ pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
      └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

on master, puppet('module list --tree') do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    └─┬ pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
      └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end


step "Install a module that requires the older module dependency be upgraded"
on master, puppet("module install pmtacceptance-apollo") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └─┬ pmtacceptance-apollo (\e[0;36mv0.0.1\e[0m)
      └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end

on master, puppet('module list') do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-apollo (\e[0;36mv0.0.1\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.7.1\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end
