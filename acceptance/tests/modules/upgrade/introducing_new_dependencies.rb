begin test_name "puppet module upgrade (introducing new dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, <<-'MANIFEST1'
file { '/usr/share/puppet':
  ensure  => directory,
}
file { ['/etc/puppet/modules', '/usr/share/puppet/modules']:
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
MANIFEST1
on master, puppet("module install pmtacceptance-stdlib --version 1.0.0")
on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.2")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (\e[0;36mv1.7.0\e[0m)
    ├── pmtacceptance-postgresql (\e[0;36mv0.0.2\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a module to a version that introduces new dependencies"
on master, puppet("module upgrade pmtacceptance-postgresql") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-postgresql' ...
    Found 'pmtacceptance-postgresql' (\e[0;36mv0.0.2\e[0m) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └─┬ pmtacceptance-postgresql (\e[0;36mv0.0.2 -> v1.0.0\e[0m)
      └── pmtacceptance-geordi (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
end
