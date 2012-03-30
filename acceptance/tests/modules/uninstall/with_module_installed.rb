begin test_name "puppet module uninstall (with module installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
  ]: ensure => directory;
  '/etc/puppet/modules/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn') do
  assert_output <<-OUTPUT
    Preparing to uninstall 'jimmy-crakorn' ...
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from /etc/puppet/modules
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/crakorn ]'

ensure step "Teardown"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
end
