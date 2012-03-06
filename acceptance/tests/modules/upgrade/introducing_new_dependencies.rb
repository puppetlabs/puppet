begin test_name "puppet module upgrade (introducing new dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-stdlib --version 1.0.0")
on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.2")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (v1.7.0)
    ├── pmtacceptance-postgresql (v0.0.2)
    └── pmtacceptance-stdlib (v1.0.0)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a module to a version that introduces new dependencies"
on master, puppet("module upgrade pmtacceptance-postgresql") do
  assert_output <<-OUTPUT
    Finding module 'pmtacceptance-postgresql' in module path ...
    Preparing to upgrade /etc/puppet/modules/postgresql ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └─┬ pmtacceptance-postgresql (v0.0.2 -> v1.0.0)
      ├── pmtacceptance-geordi (v0.0.1)
      └── pmtacceptance-stdlib (v0.0.2 -> v1.0.0)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
