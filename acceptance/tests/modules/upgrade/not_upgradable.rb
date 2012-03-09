begin test_name "puppet module upgrade (not upgradable)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
apply_manifest_on master, <<-PP
  file {
    [
      '/etc/puppet/modules/nginx',
      '/etc/puppet/modules/unicorns',
    ]: ensure => directory;
    '/etc/puppet/modules/unicorns/metadata.json':
      content => '{
        "name": "notpmtacceptance/unicorns",
        "version": "0.0.3",
        "source": "",
        "author": "notpmtacceptance",
        "license": "MIT",
        "dependencies": []
      }';
  }
PP
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── nginx (???)
    ├── notpmtacceptance-unicorns (v0.0.3)
    ├── pmtacceptance-java (v1.6.0)
    └── pmtacceptance-stdlib (v1.0.0)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Try to upgrade a module that is not installed"
on master, puppet("module upgrade pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-nginx' ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-nginx' (??? -> latest)
    STDERR>   Module 'pmtacceptance-nginx' is not installed
    STDERR>     Use `puppet module install` to install this module\e[0m
  OUTPUT
end

step "Try to upgrade a local module"
on master, puppet("module upgrade nginx") do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'nginx' ...
    STDOUT> Found 'nginx' (???) in /etc/puppet/modules ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'nginx' (??? -> latest)
    STDERR>   Module 'nginx' does not exist on http://forge.puppetlabs.com\e[0m
  OUTPUT
end

step "Try to upgrade a module that doesn't exist"
on master, puppet("module upgrade notpmtacceptance-unicorns") do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'notpmtacceptance-unicorns' ...
    STDOUT> Found 'notpmtacceptance-unicorns' (v0.0.3) in /etc/puppet/modules ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'notpmtacceptance-unicorns' (v0.0.3 -> latest)
    STDERR>   Module 'notpmtacceptance-unicorns' does not exist on http://forge.puppetlabs.com\e[0m
  OUTPUT
end

step "Try to upgrade an installed module to a version that doesn't exist"
on master, puppet("module upgrade pmtacceptance-java --version 2.0.0") do
  assert_output <<-OUTPUT
    STDOUT> Preparing to upgrade 'pmtacceptance-java' ...
    STDOUT> Found 'pmtacceptance-java' (v1.6.0) in /etc/puppet/modules ...
    STDOUT> Downloading from http://forge.puppetlabs.com ...
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.6.0 -> v2.0.0)
    STDERR>   No version matching '2.0.0' exists on http://forge.puppetlabs.com\e[0m
  OUTPUT
end

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
