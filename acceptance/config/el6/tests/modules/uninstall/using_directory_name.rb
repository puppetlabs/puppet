test_name "puppet module uninstall (using directory name)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/apache',
    '/etc/puppet/modules/crakorn',
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
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
end
on master, '[ -d /etc/puppet/modules/apache ]'
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Try to uninstall the module apache"
on master, puppet('module uninstall apache') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'apache' ...\e[0m
    Removed 'apache' from /etc/puppet/modules
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/apache ]'

step "Try to uninstall the module crakorn"
on master, puppet('module uninstall crakorn'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'crakorn' ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'crakorn'
    STDERR>   Module 'crakorn' is not installed
    STDERR>     You may have meant `puppet module uninstall jimmy-crakorn`\e[0m
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
