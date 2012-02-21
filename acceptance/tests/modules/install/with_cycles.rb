begin test_name "puppet module install (with cycles)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"

step "Install a module with cycles"
on master, "puppet module install pmtacceptance-php" do
  assert_equal '', stderr
end

on master, 'puppet module list' do
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
pmtacceptance-apache (0.0.1)
pmtacceptance-php (0.0.2)
pmtacceptance-stdlib (0.0.1)
/usr/share/puppet/modules (No modules installed)
STDOUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
