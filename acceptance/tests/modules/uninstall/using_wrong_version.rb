test_name "puppet module uninstall (with module installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
  ]: ensure => directory;
  '/etc/puppet/modules/crakorn/metadata.json':
    content => '{ "full_name": "jimmy/crakorn", "version": "0.4.0" }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Try to uninstall the module crakorn"
on master, puppet('module uninstall crakorn --version 0.5.x') do
  # TODO: Assert output.
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
