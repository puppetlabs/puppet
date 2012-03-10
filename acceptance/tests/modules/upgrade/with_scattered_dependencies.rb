begin test_name "puppet module upgrade (with scattered dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-stdlib --version 0.0.2 --dir /usr/share/puppet/modules")
on master, puppet("module install pmtacceptance-java --version 1.6.0 --dir /etc/puppet/modules --ignore-dependencies")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.1 --dir /etc/puppet/modules --ignore-dependencies")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (v1.6.0)
    └── pmtacceptance-postgresql (v0.0.1)
    /usr/share/puppet/modules
    └── pmtacceptance-stdlib (v0.0.2)
  OUTPUT
end

step "Upgrade a module that has a more recent version published"
on master, puppet("module upgrade pmtacceptance-postgresql --version 0.0.2") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-postgresql' ...
    Found 'pmtacceptance-postgresql' (v0.0.1) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └─┬ pmtacceptance-postgresql (v0.0.1 -> v0.0.2)
      ├─┬ pmtacceptance-java (v1.6.0 -> v1.7.0)
      │ └── pmtacceptance-stdlib (v0.0.2 -> v1.0.0) [/usr/share/puppet/modules]
      └── pmtacceptance-stdlib (v0.0.2 -> v1.0.0) [/usr/share/puppet/modules]
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
