test_name "puppet module upgrade (from a valid tarball)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
  on master, "rm -rf /tmp/pmtacceptance-*"
end

step "Try to install a module without dependencies from a tarball"
on master, puppet("module install pmtacceptance-stdlib --version 0.0.1")
on master, 'curl -sg \'https://forge.puppetlabs.com/pmtacceptance/stdlib/1.0.0.tar.gz\' -o /tmp/pmtacceptance-stdlib-1.0.0.tar.gz'
on master, puppet("module upgrade /tmp/pmtacceptance-stdlib-1.0.0.tar.gz") do
  assert_output <<-OUTPUT
    \e[mNotice: Reading metadata from '/tmp/pmtacceptance-stdlib-1.0.0.tar.gz' ...\e[0m
    \e[mNotice: Preparing to upgrade 'pmtacceptance-stdlib' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-stdlib' (\e[0;36mv0.0.1\e[m) in /etc/puppet/modules ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-stdlib (\e[0;36mv0.0.1 -> v1.0.0\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/stdlib ]'

step "Try to install a module from a tarball with all dependencies satisfied locally"
on master, puppet("module install pmtacceptance-java --version 1.6.x")
on master, 'curl -sg \'https://forge.puppetlabs.com/pmtacceptance/java/1.7.0.tar.gz\' -o /tmp/pmtacceptance-java-1.7.0.tar.gz'
on master, puppet("module upgrade /tmp/pmtacceptance-java-1.7.0.tar.gz") do
  assert_output <<-OUTPUT
    \e[mNotice: Reading metadata from '/tmp/pmtacceptance-java-1.7.0.tar.gz' ...\e[0m
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in /etc/puppet/modules ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/java ]'

step "Try to install a module from a traball which has dependencies that cannot be satisfied locally"
on master, puppet("module install pmtacceptance-postgresql --version 0.0.x")
on master, 'curl -sg \'https://forge.puppetlabs.com/pmtacceptance/postgresql/1.0.0.tar.gz\' -o /tmp/pmtacceptance-postgresql-1.0.0.tar.gz'
on master, puppet("module upgrade /tmp/pmtacceptance-postgresql-1.0.0.tar.gz") do
  assert_output <<-OUTPUT
    \e[mNotice: Reading metadata from '/tmp/pmtacceptance-postgresql-1.0.0.tar.gz' ...\e[0m
    \e[mNotice: Preparing to upgrade 'pmtacceptance-postgresql' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-postgresql' (\e[0;36mv0.0.2\e[m) in /etc/puppet/modules ...\e[0m
    \e[mNotice: Querying https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └─┬ pmtacceptance-postgresql (\e[0;36mv0.0.2 -> v1.0.0\e[0m)
      └── pmtacceptance-geordi (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/postgresql ]'
on master, '[ -d /etc/puppet/modules/geordi ]'
