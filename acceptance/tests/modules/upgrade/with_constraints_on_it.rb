begin test_name "puppet module upgrade (with constraints on it)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-apollo")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-apollo (v0.0.1)
    ├── pmtacceptance-java (v1.7.0)
    └── pmtacceptance-stdlib (v1.0.0)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a version-constrained module that has an upgrade"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    Preparing to install into /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (v1.7.0 -> v1.7.1)
  OUTPUT
end

step "Try to upgrade a version-constrained module that has no upgrade"
on master, puppet("module upgrade pmtacceptance-stdlib"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    STDOUT> Finding module 'pmtacceptance-stdlib' in module path ...
    STDOUT> Preparing to upgrade /etc/puppet/modules/stdlib ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-stdlib' (v1.0.0 -> latest: v1.0.0)
    STDERR>   The installed version is already the best fit for these dependencies:
    STDERR>     'pmtacceptance-java' (v1.7.1) requires 'pmtacceptance-stdlib' (v1.0.0)
    STDERR>     Use `puppet module install --force` to re-install this module\e[0m
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
