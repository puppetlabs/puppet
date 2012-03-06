begin test_name "puppet module upgrade (to a specific version)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (v1.6.0)
    └── pmtacceptance-stdlib (v1.0.0)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a module to a specific (greater) version"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0") do
  assert_output <<-OUTPUT
    Finding module 'pmtacceptance-java' in module path ...
    Preparing to upgrade /etc/puppet/modules/java ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (v1.6.0 -> v1.7.0)
  OUTPUT
end

step "Upgrade a module to a specific (lesser) version"
on master, puppet("module upgrade pmtacceptance-java --version 1.6.0") do
  assert_output <<-OUTPUT
    Finding module 'pmtacceptance-java' in module path ...
    Preparing to upgrade /etc/puppet/modules/java ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (v1.7.0 -> v1.6.0)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
