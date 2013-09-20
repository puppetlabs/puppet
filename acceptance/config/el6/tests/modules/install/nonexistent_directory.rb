test_name "puppet module install (nonexistent directory)"

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/tmp/modules',
  ]: ensure => absent, recurse => true, force => true;
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /tmp/modules"
end

step "Try to install a module to a non-existent directory"
on master, puppet("module install pmtacceptance-nginx --target-dir /tmp/modules") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /tmp/modules ...\e[0m
    \e[mNotice: Created target directory /tmp/modules\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /tmp/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, '[ -d /tmp/modules/nginx ]'

step "Try to install a module to a non-existent implicit directory"
on master, puppet("module install pmtacceptance-nginx") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    \e[mNotice: Created target directory /etc/puppet/modules\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

on master, '[ -d /etc/puppet/modules/nginx ]'
