test_name "puppet module install (from a valid tarball)"

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
on master, 'curl -sg \'https://forge.puppetlabs.com/pmtacceptance/stdlib/1.0.0.tar.gz\' -o /tmp/pmtacceptance-stdlib-1.0.0.tar.gz'
on master, puppet("module install /tmp/pmtacceptance-stdlib-1.0.0.tar.gz") do
  assert_output <<-OUTPUT
    \e[mNotice: Reading metadata from '/tmp/pmtacceptance-stdlib-1.0.0.tar.gz' ...\e[0m
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/stdlib ]'

step "Try to install a module from a tarball with all dependencies satisfied locally"
on master, 'curl -sg \'https://forge.puppetlabs.com/pmtacceptance/java/1.7.1.tar.gz\' -o /tmp/pmtacceptance-java-1.7.1.tar.gz'
on master, puppet("module install /tmp/pmtacceptance-java-1.7.1.tar.gz") do
  assert_output <<-OUTPUT
    \e[mNotice: Reading metadata from '/tmp/pmtacceptance-java-1.7.1.tar.gz' ...\e[0m
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.7.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/java ]'

step "Try to install a module from a traball which has dependencies that cannot be satisfied locally"
on master, 'curl -sg \'https://forge.puppetlabs.com/pmtacceptance/thin/0.0.1.tar.gz\' -o /tmp/pmtacceptance-thin-0.0.1.tar.gz'
on master, puppet("module install /tmp/pmtacceptance-thin-0.0.1.tar.gz") do
  assert_output <<-OUTPUT
    \e[mNotice: Reading metadata from '/tmp/pmtacceptance-thin-0.0.1.tar.gz' ...\e[0m
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Querying https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └─┬ pmtacceptance/thin (\e[0;36mv0.0.1\e[0m)
      └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/thin ]'
on master, '[ -d /etc/puppet/modules/nginx ]'
