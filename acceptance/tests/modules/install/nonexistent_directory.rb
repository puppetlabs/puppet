begin test_name "puppet module install (nonexistent directory)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/tmp/modules',
  ]: ensure => absent, recurse => true, force => true;
}
PP

step "Try to install a module to a non-existent directory"
on master, puppet("module install pmtacceptance-nginx --target-dir /tmp/modules"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to install into /tmp/modules ...
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (latest)
    STDERR>   Directory /tmp/modules does not exist\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/nginx ]'

step "Try to install a module to a non-existent implicit directory"
on master, puppet("module install pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to install into /etc/puppet/modules ...
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (latest)
    STDERR>   Directory /etc/puppet/modules does not exist\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/nginx ]'

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { '/etc/puppet/modules': ensure => directory }"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
