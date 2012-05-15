begin test_name "puppet module install (ignoring dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"

step "Install a module, but ignore dependencies"
on master, puppet("module install pmtacceptance-java --ignore-dependencies") do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.7.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/java ]'
on master, '[ ! -d /etc/puppet/modules/stdlib ]'

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
