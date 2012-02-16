begin test_name "puppet module install a module without dependencies"

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step "Try to install a module without deps"
expected_stderr = ''

on master, "puppet module install pmtacceptance-nginx" do
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
└── nginx (v0.0.1)
STDOUT

  assert_equal '', stderr
end

ensure step "Unstub http://forge.puppetlabs.com"
	apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
  apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
