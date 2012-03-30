begin test_name "puppet module upgrade (to installed version)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Try to upgrade a module to the current version"
on master, puppet("module upgrade pmtacceptance-java --version 1.6.x"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-java' ...
    STDOUT> Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[0m) in /etc/puppet/modules ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.6.0 -> v1.6.x)
    STDERR>   The installed version is already the best fit for the current dependencies
    STDERR>     You specified 'pmtacceptance-java' (v1.6.x)
    STDERR>     Use `puppet module install --force` to re-install this module\e[0m
  OUTPUT
end

step "Upgrade a module to the current version with --force"
on master, puppet("module upgrade pmtacceptance-java --version 1.6.x --force") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[0m) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.6.0\e[0m)
  OUTPUT
end

step "Upgrade to the latest version"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[0m) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end

step "Try to upgrade a module to the latest version with the latest version installed"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-java' ...
    STDOUT> Found 'pmtacceptance-java' (\e[0;36mv1.7.1\e[0m) in /etc/puppet/modules ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.7.1 -> latest: v1.7.1)
    STDERR>   The installed version is already the latest version
    STDERR>     Use `puppet module install --force` to re-install this module\e[0m
  OUTPUT
end

step "Upgrade a module to the latest version with --force"
on master, puppet("module upgrade pmtacceptance-java --force") do
  assert_output <<-OUTPUT
    Preparing to upgrade 'pmtacceptance-java' ...
    Found 'pmtacceptance-java' (\e[0;36mv1.7.1\e[0m) in /etc/puppet/modules ...
    Downloading from http://forge.puppetlabs.com ...
    Upgrading -- do not interrupt ...
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.7.1 -> v1.7.1\e[0m)
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
end
