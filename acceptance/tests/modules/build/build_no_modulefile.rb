begin test_name "puppet module build (bad modulefiles)"

step 'Setup'
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules/nginx',
  ]: ensure => directory;
  '/etc/puppet/modules/nginx/Modulefile':
    ensure => absent;
}
PP

step "Try to build a module with no modulefile"
on master, puppet("module build /etc/puppet/modules/nginx"), :acceptable_exit_codes => [1] do
  assert_equal <<-OUTPUT, stderr
\e[1;31mError: Unable to find module root at /etc/puppet/modules/nginx\e[0m
\e[1;31mError: Try 'puppet help module build' for usage\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1 ]'
on master, '[ ! -f /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz ]'

ensure step "Teardown"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
