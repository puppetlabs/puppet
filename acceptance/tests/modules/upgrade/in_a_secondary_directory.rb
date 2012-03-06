begin test_name "puppet module upgrade (in a secondary directory)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-java --version 1.6.0 --dir /usr/share/puppet/modules")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules (no modules installed)
    /usr/share/puppet/modules
    ├── pmtacceptance-java (v1.6.0)
    └── pmtacceptance-stdlib (v1.0.0)
  OUTPUT
end

step "Upgrade a module that has a more recent version published"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    Finding module 'pmtacceptance-java' in module path ...
    Preparing to upgrade /usr/share/puppet/modules/java ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /usr/share/puppet/modules
    └── pmtacceptance-java (v1.6.0 -> v1.7.1)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
