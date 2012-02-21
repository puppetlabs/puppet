begin test_name "puppet module install (already installed)"

step 'Setup'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules/nginx',
  ]: ensure => directory;
  '/etc/puppet/modules/nginx/metadata.json':
    content => '{
      "name": "pmtacceptance/nginx",
      "version": "0.0.1",
      "source": "",
      "author": "pmtacceptance",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

step "Try to install a module that is already installed"
on master, puppet("module install pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_equal <<-STDERR, stderr
Could not install module 'pmtacceptance-nginx' (latest):
  Module 'pmtacceptance-nginx' is already installed (v0.0.1)
    Use `puppet module upgrade` to install a different version
    Use `puppet module install --force` to re-install only this module
STDERR
  assert_equal <<-STDOUT, stdout
Preparing to install into /etc/puppet/modules ...
STDOUT
end
on master, '[ ! -d /etc/puppet/modules/nginx ]'

step "Try to install a specific version of a module that is already installed"
on master, puppet("module install pmtacceptance-nginx --version 1.x"), :acceptable_exit_codes => [1] do
  assert_equal <<-STDERR, stderr
Could not install module 'pmtacceptance-nginx' (v1.x):
  Module 'pmtacceptance-nginx' is already installed (v0.0.1)
    Use `puppet module upgrade` to install a different version
    Use `puppet module install --force` to re-install only this module
STDERR
  assert_equal <<-STDOUT, stdout
Preparing to install into /etc/puppet/modules ...
STDOUT
end
on master, '[ ! -d /etc/puppet/modules/nginx ]'

step "Install a module that is already installed (with --force)"
on master, puppet("module install pmtacceptance-nginx --version 1.x") do
  assert_equal <<-STDERR, stderr
STDERR
  assert_equal <<-STDOUT, stdout
Preparing to install into /etc/puppet/modules ...
Downloading from http://forge.puppetlabs.com ...
Installing -- do not interrupt ...
/etc/puppet/modules
└── pmtacceptance-nginx (v0.0.1)
STDOUT
end
on master, '[ -d /etc/puppet/modules/nginx ]'

ensure step "Teardown"
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
