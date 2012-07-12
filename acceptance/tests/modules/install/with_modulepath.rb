begin test_name "puppet module install (with modulepath)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules2']: ensure => directory, recurse => true, purge => true, force => true }"

step "Install a module with relative modulepath"
on master, "cd /etc/puppet/modules2 && puppet module install pmtacceptance-nginx --modulepath=." do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules2 ...
    Downloading from https://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /etc/puppet/modules2
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules2/nginx ]'
apply_manifest_on master, "file { ['/etc/puppet/modules2']: ensure => directory, recurse => true, purge => true, force => true }"

step "Install a module with absolute modulepath"
on master, puppet('module install pmtacceptance-nginx --modulepath=/etc/puppet/modules2') do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules2 ...
    Downloading from https://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /etc/puppet/modules2
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules2/nginx ]'
apply_manifest_on master, "file { ['/etc/puppet/modules2']: ensure => directory, recurse => true, purge => true, force => true }"

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules2']: ensure => directory, recurse => true, purge => true, force => true }"
end
