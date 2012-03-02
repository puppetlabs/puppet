begin test_name "puppet module install (already installed)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/tmp/modules',
  ]: ensure => absent;
}
PP

step "Try to install a module to a non-existent directory"
on master, puppet("module install pmtacceptance-nginx --dir /tmp/modules"), :acceptable_exit_codes => [1] do
  assert_equal <<-STDERR, stderr
Could not install module 'pmtacceptance-nginx' (latest):
  Directory /tmp/modules does not exist
STDERR
  assert_equal '', stdout
end
on master, '[ ! -d /etc/puppet/modules/nginx ]'

step "Try to install a module to a non-existent implicit directory"
on master, puppet("module install pmtacceptance-nginx") do
  assert_equal <<-STDERR, stderr
Could not install module 'pmtacceptance-nginx' (latest):
  Directory /etc/puppet/modules does not exist
STDERR
  assert_equal '', stdout
end
on master, '[ -d /etc/puppet/modules/nginx ]'

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
