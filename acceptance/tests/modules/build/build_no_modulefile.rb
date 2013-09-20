begin test_name "puppet module build (bad modulefiles)"

step 'Setup'
apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/nginx',
  ]: ensure => directory;
  '#{master['distmoduledir']}/nginx/Modulefile':
    ensure => absent;
}
PP

step "Try to build a module with no modulefile"
on master, puppet("module build #{master['distmoduledir']}/nginx"), :acceptable_exit_codes => [1] do
  assert_equal <<-OUTPUT, stderr
\e[1;31mError: Unable to find module root at #{master['distmoduledir']}/nginx\e[0m
\e[1;31mError: Try 'puppet help module build' for usage\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1 ]"
on master, "[ ! -f #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz ]"

ensure step "Teardown"
  apply_manifest_on master, "file { '#{master['distmoduledir']}/nginx': ensure => absent, force => true }"
end
