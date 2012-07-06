begin test_name "puppet module upgrade (with constraints on it)"

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
on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-apollo")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-apollo (\e[0;36mv0.0.1\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.7.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a version-constrained module that has an upgrade"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (\e[0;36mv1.7.0\e[0m) in /etc/puppet/modules ...
    Downloading from https://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.7.0 -> v1.7.1\e[0m)
  OUTPUT
end

step "Try to upgrade a version-constrained module that has no upgrade"
on master, puppet("module upgrade pmtacceptance-stdlib"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-stdlib' ...
    STDOUT> Found 'pmtacceptance-stdlib' (\e[0;36mv1.0.0\e[0m) in /etc/puppet/modules ...
    STDOUT> Downloading from https://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-stdlib' (v1.0.0 -> best: v1.0.0)
    STDERR>   The installed version is already the best fit for the current dependencies
    STDERR>     'pmtacceptance-apollo' (v0.0.1) requires 'pmtacceptance-stdlib' (>= 1.0.0)
    STDERR>     'pmtacceptance-java' (v1.7.1) requires 'pmtacceptance-stdlib' (v1.0.0)
    STDERR>     Use `puppet module install --force` to re-install this module\e[0m
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
end
