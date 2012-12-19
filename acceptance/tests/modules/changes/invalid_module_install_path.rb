test_name 'puppet module changes (on an invalid module install path)'

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, %q{file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }}
teardown do
  on master, 'rm -rf /etc/puppet/modules'
  on master, 'rm -rf /usr/share/puppet/modules'
end

step 'Run module changes on an invalid module install path'
on master, puppet('module changes /etc/puppet/modules/nginx'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDERR> \e[1;31mError: Could not find a valid module at "/etc/puppet/modules/nginx"\e[0m
    STDERR> \e[1;31mError: Try 'puppet help module changes' for usage\e[0m
  OUTPUT
end
