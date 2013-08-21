test_name 'puppet module changes (on an unmodified module)'

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, %q{file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }}
teardown do
  on master, 'rm -rf /etc/puppet/modules'
  on master, 'rm -rf /usr/share/puppet/modules'
end

on master, puppet('module install pmtacceptance-nginx')

step 'Run module changes to check an unmodified module'
on master, puppet('module changes /etc/puppet/modules/nginx'), :acceptable_exit_codes => [0] do
  assert_match /No modified files/, stdout
end
