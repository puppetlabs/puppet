test_name 'puppet module uninstall (with environment)'

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
      '/etc/puppet/testenv/modules/crakorn',
    ]:
      ensure => directory,
  }
  file {
    '/etc/puppet/testenv/modules/crakorn/metadata.json':
      content => '{
        "name": "jimmy/crakorn",
        "version": "0.4.0",
        "source": "",
        "author": "jimmy",
        "license": "MIT",
        "dependencies": []
      }',
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

step 'Uninstall a module from a non default environment'
on master, 'puppet module uninstall jimmy-crakorn --environment=testenv' do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from /etc/puppet/testenv/modules
  OUTPUT
end
on master, '[ ! -d /etc/puppet/testenv/modules/nginx ]'
