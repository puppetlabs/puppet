begin test_name "puppet module uninstall (with active dependency)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
    '/etc/puppet/modules/appleseed',
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
  '/etc/puppet/modules/appleseed/metadata.json':
    content => '{
      "name": "jimmy/appleseed",
      "version": "1.1.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crakorn", "version_requirement": "0.4.0" }
      ]
    }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'

step "Try to uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn'), :acceptable_exit_codes => [1] do
  assert_equal '', stdout
  assert_equal <<-STDERR, stderr
Error: Could not uninstall module 'jimmy-crakorn' (v0.4.0):
  Module 'jimmy-crakorn' (v0.4.0) is required by 'jimmy-appleseed' (v1.1.0)
    Supply the `--force` flag to uninstall this module anyway
STDERR
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'

ensure step "Teardown"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
