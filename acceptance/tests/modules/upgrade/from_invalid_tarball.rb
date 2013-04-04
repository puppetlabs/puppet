test_name "puppet module upgrade (from an invalid tarball)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
  on master, "rm -rf /tmp/pmtacceptance-*"
end

step "Try to upgrade a module from a nonexistent tarball"
on master, 'rm -f /tmp/pmtacceptance-stdlib-10.0.0.tar.gz'
on master, puppet("module upgrade /tmp/pmtacceptance-stdlib-10.0.0.tar.gz"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Reading metadata from '/tmp/pmtacceptance-stdlib-10.0.0.tar.gz' ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade from package /tmp/pmtacceptance-stdlib-10.0.0.tar.gz
    STDERR>   Package /tmp/pmtacceptance-stdlib-10.0.0.tar.gz does not exist\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/stdlib ]'

step "Try to upgrade a module from an empty tarball"
on master, 'touch /tmp/pmtacceptance-stdlib-11.0.0.tar.gz'
on master, puppet("module upgrade /tmp/pmtacceptance-stdlib-11.0.0.tar.gz"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Reading metadata from '/tmp/pmtacceptance-stdlib-11.0.0.tar.gz' ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade from package /tmp/pmtacceptance-stdlib-11.0.0.tar.gz
    STDERR>   Error during extraction of module metadata: not in gzip format\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/stdlib ]'

step "Try to upgrade a module from a tarball without metadata"
on master, 'mkdir /tmp/pmtacceptance-stdlib-12.0.0'
on master, 'tar -czf /tmp/pmtacceptance-stdlib-12.0.0.tar.gz -C /tmp pmtacceptance-stdlib-12.0.0'
on master, puppet("module upgrade /tmp/pmtacceptance-stdlib-12.0.0.tar.gz"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Reading metadata from '/tmp/pmtacceptance-stdlib-12.0.0.tar.gz' ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade from package /tmp/pmtacceptance-stdlib-12.0.0.tar.gz
    STDERR>   The package is missing metadata file: metadata.json\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/stdlib ]'

step "Try to upgrade a module from a tarball with invalid metadata"
on master, 'mkdir /tmp/pmtacceptance-stdlib-13.0.0'
on master, 'touch /tmp/pmtacceptance-stdlib-13.0.0/metadata.json'
on master, 'tar -czf /tmp/pmtacceptance-stdlib-13.0.0.tar.gz -C /tmp pmtacceptance-stdlib-13.0.0'
on master, puppet("module upgrade /tmp/pmtacceptance-stdlib-13.0.0.tar.gz"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Reading metadata from '/tmp/pmtacceptance-stdlib-13.0.0.tar.gz' ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade from package /tmp/pmtacceptance-stdlib-13.0.0.tar.gz
    STDERR>   Error during extraction of module metadata: can't convert nil into String\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/stdlib ]'
