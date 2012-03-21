begin test_name "puppet module install (with cycles)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"

step "Install a module with cycles"
on master, puppet("module install pmtacceptance-php --version 0.0.1") do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /etc/puppet/modules
    └─┬ pmtacceptance-php (v0.0.1)
      └── pmtacceptance-apache (v0.0.1)
  OUTPUT
end

on master, puppet('module list') do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-apache (v0.0.1)
    └── pmtacceptance-php (v0.0.1)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
end
