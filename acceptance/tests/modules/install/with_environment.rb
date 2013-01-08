test_name 'puppet module install (with environment)'

step 'Setup'

stub_forge_on(master)

# Configure a non-default environment
on master, 'rm -rf /usr/share/puppet/modules /etc/puppet/testenv'
apply_manifest_on master, %q{
  file {
    [
      '/usr/share/puppet/modules',
      '/etc/puppet/testenv',
      '/etc/puppet/testenv/modules',
    ]:
      ensure => directory,
  }
  augeas {
    'set-testenv-modulepath':
      incl => $settings::config,
      lens => 'Puppet.lns',
      context => "/files${settings::config}",
      changes => [
        'set testenv/modulepath /etc/puppet/testenv/modules',
      ],
  }
}
teardown do
apply_manifest_on master, %q{
  augeas {
    'delete-testenv-settings':
      incl => $settings::config,
      lens => 'Puppet.lns',
      context => "/files${settings::config}",
      changes => [
        'rm testenv',
      ],
  }
}
on master, 'rm -rf /usr/share/puppet/modules /etc/puppet/testenv'
end

step 'Install a module into a non default environment'
on master, 'puppet module install pmtacceptance-nginx --environment=testenv' do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/testenv/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/testenv/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/testenv/modules/nginx ]'
