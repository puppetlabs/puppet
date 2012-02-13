begin test_name "puppet module uninstall (using directory name)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/apache',
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
on master, '[ -d /etc/puppet/modules/apache ]'
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Try to uninstall the module apache"
on master, puppet('module uninstall apache') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Removed module /etc/puppet/modules/apache
STDOUT
end
on master, '[ ! -d /etc/puppet/modules/apache ]'

step "Try to uninstall the module crakorn"
on master, puppet('module uninstall crakorn'), :acceptable_exit_codes => [1] do
  assert_equal '', stdout
  assert_equal <<-STDERR, stderr
Error: Could not uninstall module 'crakorn':
  Module 'crakorn' is not installed
    You may have meant `puppet module uninstall jimmy-crakorn`
STDERR
end
on master, '[ -d /etc/puppet/modules/crakorn ]'

ensure step "Teardown"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
