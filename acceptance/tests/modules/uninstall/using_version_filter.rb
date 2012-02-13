begin test_name "puppet module uninstall (with module installed)"

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
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
  '/usr/share/puppet/modules/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "v0.5.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /usr/share/puppet/modules/crakorn ]'

step "Uninstall jimmy-crakorn version 0.5.x"
on master, puppet('module uninstall jimmy-crakorn --version 0.5.x') do
  assert_equal '', stdout
  assert_equal 'Removed /usr/share/puppet/modules/crakorn (v0.5.1)', stderr
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ ! -d /usr/share/puppet/modules/crakorn ]'

step "Try to uninstall jimmy-crakorn v0.4.0 with `--version 0.5.x`"
on master, puppet('module uninstall jimmy-crakorn --version 0.5.x') do
  assert_equal '', stdout
  assert_equal <<-STDERR, stderr
Error: Could not uninstall module 'jimmy-crakorn' (v0.5.x):
  Installed version of 'jimmy-crakorn' (v0.4.0) does not match (v0.5.x)
STDERR
end
on master, '[ -d /etc/puppet/modules/crakorn ]'

ensure step "Teardown"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
