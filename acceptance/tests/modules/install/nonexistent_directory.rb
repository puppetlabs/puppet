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
on master, puppet("module install pmtacceptance-nginx --target-dir /tmp/modules") do
  assert_output <<-OUTPUT
    Preparing to install into /tmp/modules ...
    Created target directory /tmp/modules
    Downloading from http://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /tmp/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /tmp/modules/nginx ]'

step "Try to install a module to a non-existent implicit directory"
on master, puppet("module install pmtacceptance-nginx") do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules ...
    Created target directory /etc/puppet/modules
    Downloading from http://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/nginx ]'

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { '/etc/puppet/modules': ensure => directory }"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
