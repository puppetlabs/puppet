test_name "puppet module install (already installed with local changes)"

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

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
      "checksums": {
        "README": "2a3adc3b053ef1004df0a02cefbae31f"
      },
      "dependencies": []
    }';
  '/etc/puppet/modules/nginx/README':
    content => 'Nginx module';
}
PP

step "Try to install a module that is already installed"
on master, puppet("module install pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (latest)
    STDERR>   Module 'pmtacceptance-nginx' (v0.0.1) is already installed
    STDERR>     Installed module has had changes made locally
    STDERR>     Use `puppet module upgrade` to install a different version
    STDERR>     Use `puppet module install --force` to re-install only this module\e[0m
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/nginx ]'

step "Try to install a specific version of a module that is already installed"
on master, puppet("module install pmtacceptance-nginx --version 1.x"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (v1.x)
    STDERR>   Module 'pmtacceptance-nginx' (v0.0.1) is already installed
    STDERR>     Installed module has had changes made locally
    STDERR>     Use `puppet module upgrade` to install a different version
    STDERR>     Use `puppet module install --force` to re-install only this module\e[0m
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/nginx ]'

step "Install a module that is already installed (with --force)"
on master, puppet("module install pmtacceptance-nginx --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/nginx ]'
