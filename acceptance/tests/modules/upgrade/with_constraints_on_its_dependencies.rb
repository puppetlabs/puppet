begin test_name "puppet module upgrade (with constraints on its dependencies)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-stdlib --version 0.0.2")
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.1")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (v1.6.0)
    ├── pmtacceptance-postgresql (v0.0.1)
    └── pmtacceptance-stdlib (v0.0.2)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Try to upgrade a module with constraints on its dependencies that cannot be met"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-java' ...
    STDOUT> Found 'pmtacceptance-java' (v1.6.0) in /etc/puppet/modules ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.6.0 -> latest: v1.7.1)
    STDERR>   No version of 'pmtacceptance-stdlib' will satisfy dependencies:
    STDERR>     'pmtacceptance-java' (v1.7.1) requires 'pmtacceptance-stdlib' (v1.0.0)
    STDERR>     'pmtacceptance-postgresql' (v0.0.1) requires 'pmtacceptance-stdlib' (v0.0.2)
    STDERR>     Use `puppet module upgrade --force` to install this module anyway\e[0m
  OUTPUT
end

step "Relax constraints"
on master, puppet("module uninstall pmtacceptance-postgresql")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (v1.6.0)
    └── pmtacceptance-stdlib (v0.0.2)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a single module, ignoring its dependencies"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0 --ignore-dependencies") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (v1.6.0) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (v1.6.0 -> v1.7.0)
  OUTPUT
end

step "Upgrade a module with constraints on its dependencies that can be met"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (v1.7.0) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └─┬ pmtacceptance-java (v1.7.0 -> v1.7.1)
      └── pmtacceptance-stdlib (v0.0.2 -> v1.0.0)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
