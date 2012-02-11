test_name "puppet module uninstall (with module installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
  ]: ensure => directory;
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Uninstall the module crakorn"
on master, puppet('module uninstall crakorn') do
  # TODO: Assert output.
end
on master, '[ ! -d /etc/puppet/modules/crakorn ]'
