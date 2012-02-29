begin test_name "puppet module list (with circular dependencies)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/appleseed',
    '/usr/share/puppet',
    '/usr/share/puppet/modules',
    '/usr/share/puppet/modules/crakorn',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '/usr/share/puppet/modules/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/appleseed", "version_requirement": "1.1.0" }
      ]
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
on master, '[ -d /etc/puppet/modules/appleseed ]'
on master, '[ -d /usr/share/puppet/modules/crakorn ]'

step "List the installed modules"
on master, puppet('module list') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
└── jimmy-appleseed (v1.1.0)
/usr/share/puppet/modules
└── jimmy-crakorn (v0.4.0)
STDOUT
end

step "List the installed modules as a dependency tree"
on master, puppet('module list --tree') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
└─┬ jimmy-appleseed (v1.1.0)
  └── jimmy-crakorn (v0.4.0) [/usr/share/puppet/modules]
/usr/share/puppet/modules
└─┬ jimmy-crakorn (v0.4.0)
  └── jimmy-appleseed (v1.1.0) [/etc/puppet/modules]
STDOUT
end

ensure step "Teardown"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
