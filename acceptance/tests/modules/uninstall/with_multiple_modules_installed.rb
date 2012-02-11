test_name "puppet module uninstall (with multiple modules installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
    '/usr/share/puppet',
    '/usr/share/puppet/modules',
    '/usr/share/puppet/modules/crakorn',
  ]: ensure => directory;
  '/etc/puppet/modules/crakorn/metadata.json':
    content => '{ "full_name": "jimmy/crakorn", "version": "0.4.0" }';
  '/usr/share/puppet/modules/crakorn/metadata.json':
    content => '{ "full_name": "jimmy/crakorn", "version": "0.4.0" }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn') do
  # TODO: Assert output.
end
on master, '[ ! -d /etc/puppet/modules/crakorn ]'
on master, '[ ! -d /usr/share/puppet/modules/crakorn ]'
