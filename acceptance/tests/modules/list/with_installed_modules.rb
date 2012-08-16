test_name "puppet module list (with installed modules)"

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
        { "name": "jimmy/crakorn", "version_requirement": "0.4.0" }
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
        { "name": "jimmy/crakorn", "version_requirement": "0.4.x" }
      ]
    }';
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'
on master, '[ -d /etc/puppet/modules/thelock ]'
on master, '[ -d /usr/share/puppet/modules/crick ]'

step "List the installed modules"
on master, puppet('module list') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
├── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)
├── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)
└── jimmy-thelock (\e[0;36mv1.0.0\e[0m)
/usr/share/puppet/modules
└── jimmy-crick (\e[0;36mv1.0.1\e[0m)
STDOUT
end

step "List the installed modules as a dependency tree"
on master, puppet('module list --tree') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules
└─┬ jimmy-thelock (\e[0;36mv1.0.0\e[0m)
  └─┬ jimmy-appleseed (\e[0;36mv1.1.0\e[0m)
    └── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)
/usr/share/puppet/modules
└─┬ jimmy-crick (\e[0;36mv1.0.1\e[0m)
  └── jimmy-crakorn (\e[0;36mv0.4.0\e[0m) [/etc/puppet/modules]
STDOUT
end
