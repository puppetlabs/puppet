begin test_name "puppet module install (force ignores dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"

step "Try to install an unsatisfiable module"
on master, puppet("module install pmtacceptance-php"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to install into /etc/puppet/modules ...
    STDOUT> Downloading from https://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-php' (latest: v0.0.2)
    STDERR>   No version of 'pmtacceptance-php' will satisfy dependencies
    STDERR>     You specified 'pmtacceptance-php' (latest: v0.0.2),
    STDERR>     which depends on 'pmtacceptance-apache' (v0.0.1),
    STDERR>     which depends on 'pmtacceptance-php' (v0.0.1)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/php ]'
on master, '[ ! -d /etc/puppet/modules/apache ]'

step "Install an unsatisfiable module with force"
on master, puppet("module install pmtacceptance-php --force") do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules ...
    Downloading from https://forge.puppetlabs.com ...
    Installing -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-php (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/php ]'
on master, '[ ! -d /etc/puppet/modules/apache ]'

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
