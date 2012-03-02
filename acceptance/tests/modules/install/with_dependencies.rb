begin test_name "puppet module install (without dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"

step "Install a module with dependencies"
on master, puppet("module install pmtacceptance-apollo") do
  assert_equal '', stderr
end

on master, puppet('module list') do
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
├── pmtacceptance-apollo (v0.0.1)
├── pmtacceptance-java (v1.7.1)
└── pmtacceptance-stdlib (v1.0.0)
/usr/share/puppet/modules (no modules installed)
STDOUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
