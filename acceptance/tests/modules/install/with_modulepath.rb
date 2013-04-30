# encoding: UTF-8

test_name "puppet module install (with modulepath)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules2', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules2"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "Install a module with relative modulepath"
on master, "cd /etc/puppet/modules2 && puppet module install pmtacceptance-nginx --modulepath=." do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules2 ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules2
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules2/nginx ]'

step "Install a module with absolute modulepath"
on master, "test -d /etc/puppet/modules2/nginx && rm -rf /etc/puppet/modules2/nginx"
on master, puppet('module install pmtacceptance-nginx --modulepath=/etc/puppet/modules2') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules2 ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules2
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /etc/puppet/modules2/nginx ]'
