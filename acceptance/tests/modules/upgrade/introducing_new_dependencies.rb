test_name "puppet module upgrade (introducing new dependencies)"

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-'MANIFEST1'
file { '/usr/share/puppet':
  ensure  => directory,
}
file { ['/etc/puppet/modules', '/usr/share/puppet/modules']:
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
MANIFEST1
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

on master, puppet("module install pmtacceptance-stdlib --version 1.0.0")
on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-postgresql --version 0.0.2")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (\e[0;36mv1.7.0\e[0m)
    ├── pmtacceptance-postgresql (\e[0;36mv0.0.2\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Upgrade a module to a version that introduces new dependencies"
on master, puppet("module upgrade pmtacceptance-postgresql") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-postgresql' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-postgresql' (\e[0;36mv0.0.2\e[m) in /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └─┬ pmtacceptance-postgresql (\e[0;36mv0.0.2 -> v1.0.0\e[0m)
      └── pmtacceptance-geordi (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
