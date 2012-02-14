begin test_name "puppet module list"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
    '/etc/puppet/modules/appleseed',
    '/etc/puppet/modules/thelock',
    '/usr/share/puppet',
    '/usr/share/puppet/modules',
    '/usr/share/puppet/modules/crick',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
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
        { "name": "jimmy/crackorn", "version_requirement": "0.4.0" }
      ]
    }';
  '/etc/puppet/modules/thelock/metadata.json':
    content => '{
      "name": "jimmy/thelock",
      "version": "1.0.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/appleseed", "version_requirement": "1.x" }
      ]
    }';
  '/usr/share/puppet/modules/crick/metadata.json':
    content => '{
      "name": "jimmy/crick",
      "version": "1.0.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crackorn", "version_requirement": "v0.4.x" }
      ]
    }';
}
PP
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'
on master, '[ -d /etc/puppet/modules/thelock ]'
on master, '[ -d /usr/share/puppet/modules/crick ]'

step "List the installed modules"
on master, puppet('module list') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
├── jimmy-appleseed (v1.1.0)
├── jimmy-crakorn (v0.4.0)
└── jimmy-thelock (v1.0.0)
/usr/share/puppet/modules
└── jimmy-crick (v1.0.1)
STDOUT
end

step "List the installed modules as a dependency tree"
on master, puppet('module list') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
└─┬ jimmy-thelock (v1.0.0)
  └─┬ jimmy-appleseed (v1.1.0)
    └── jimmy-crakorn (v0.4.0)
/usr/share/puppet/modules
└─┬ jimmy-crick (v1.0.1)
  └── jimmy-crakorn (v0.4.0) [/etc/puppet/modules]
STDOUT
end

ensure step "Teardown"
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: recurse => true, purge => true, force => true }"
end
