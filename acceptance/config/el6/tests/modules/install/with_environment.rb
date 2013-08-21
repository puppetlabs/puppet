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
  file {
    '/etc/puppet/puppet2.conf':
      source => $settings::config,
  }
}
on master, '{ echo "[testenv]"; echo "modulepath=/etc/puppet/testenv/modules"; } >> /etc/puppet/puppet2.conf'
teardown do
on master, 'rm -rf /usr/share/puppet/modules /etc/puppet/testenv /etc/puppet/puppet2.conf'
end

step 'Install a module into a non default environment'
on master, 'puppet module install pmtacceptance-nginx --config=/etc/puppet/puppet2.conf --environment=testenv' do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/testenv/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/testenv/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/testenv/modules/nginx ]'
