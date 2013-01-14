test_name "puppet module install (ignoring dependencies)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "Install a module, but ignore dependencies"
on master, puppet("module install pmtacceptance-java --ignore-dependencies") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.7.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/java ]'
on master, '[ ! -d /etc/puppet/modules/stdlib ]'
