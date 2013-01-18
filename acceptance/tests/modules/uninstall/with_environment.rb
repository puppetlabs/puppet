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
  file {
    '/etc/puppet/puppet2.conf':
      source => $settings::config,
  }
}
on master, '{ echo "[testenv]"; echo "modulepath=/etc/puppet/testenv/modules"; } >> /etc/puppet/puppet2.conf'
teardown do
on master, 'rm -rf /usr/share/puppet/modules /etc/puppet/testenv /etc/puppet/puppet2.conf'
end

step 'Uninstall a module from a non default environment'
on master, 'puppet module uninstall jimmy-crakorn --config=/etc/puppet/puppet2.conf --environment=testenv' do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from /etc/puppet/testenv/modules
  OUTPUT
end
on master, '[ ! -d /etc/puppet/testenv/modules/crakorn ]'
