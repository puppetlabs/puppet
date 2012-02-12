test_name "puppet module uninstall (with active dependency)"

step "Setup"
on master, 'whoami'
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
    '/etc/puppet/modules/appleseed',
  ]: ensure => directory;
  '/etc/puppet/modules/crakorn/metadata.json':
    content => '{ "full_name": "jimmy/crakorn", "version": "0.4.0" }';
  '/etc/puppet/modules/appleseed/metadata.json':
    content => '{ "full_name": "jimmy/appleseed", "version": "1.1.0", "dependencies": { "jimmy/crackorn": "0.4.0" } }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn') do
  # TODO: Assert output.
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
