test_name "puppet module list (without installed modules)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/usr/share/puppet/modules',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "List the installed modules"
on master, puppet('module list') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules (no modules installed)
/usr/share/puppet/modules (no modules installed)
STDOUT
end

step "List the installed modules as a dependency tree"
on master, puppet('module list') do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
/etc/puppet/modules (no modules installed)
/usr/share/puppet/modules (no modules installed)
STDOUT
end
