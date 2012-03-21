begin test_name "puppet module upgrade (that was installed twice)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-java --version 1.6.0 --dir /etc/puppet/modules")
on master, puppet("module install pmtacceptance-java --version 1.7.0 --dir /usr/share/puppet/modules")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (v1.6.0)
    └── pmtacceptance-stdlib (v1.0.0)
    /usr/share/puppet/modules
    ├── pmtacceptance-java (v1.7.0)
    └── pmtacceptance-stdlib (v1.0.0)
  OUTPUT
end

step "Try to upgrade a module that exists multiple locations in the module path"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-java' ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java'
    STDERR>   Module 'pmtacceptance-java' appears multiple places in the module path
    STDERR>     'pmtacceptance-java' (v1.6.0) was found in /etc/puppet/modules
    STDERR>     'pmtacceptance-java' (v1.7.0) was found in /usr/share/puppet/modules
    STDERR>     Use the `--modulepath` option to limit the search to specific directories\e[0m
  OUTPUT
end

step "Upgrade a module that exists multiple locations by restricting the --modulepath"
on master, puppet("module upgrade pmtacceptance-java --modulepath /etc/puppet/modules") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (v1.6.0) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (v1.6.0 -> v1.7.1)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
end
