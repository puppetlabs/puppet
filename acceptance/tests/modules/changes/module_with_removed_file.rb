test_name 'puppet module changes (on a module with a removed file)'

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, %q{file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }}
teardown do
  on master, 'rm -rf /etc/puppet/modules'
  on master, 'rm -rf /usr/share/puppet/modules'
end

on master, puppet('module install pmtacceptance-nginx')
on master, 'rm -rf /etc/puppet/modules/nginx/README'

step 'Run module changes to check a module with a removed file'
on master, puppet('module changes /etc/puppet/modules/nginx'), :acceptable_exit_codes => [0] do
  assert_equal <<-STDERR, stderr
\e[1;31mWarning: 1 files modified\e[0m
  STDERR
  assert_equal <<-OUTPUT, stdout
README
  OUTPUT
end
