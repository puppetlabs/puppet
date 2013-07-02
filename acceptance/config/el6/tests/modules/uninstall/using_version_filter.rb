test_name "puppet module uninstall (with module installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
    '/usr/share/puppet',
    '/usr/share/puppet/modules',
    '/usr/share/puppet/modules/crakorn',
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
  '/usr/share/puppet/modules/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.5.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /usr/share/puppet/modules/crakorn ]'

step "Uninstall jimmy-crakorn version 0.5.x"
on master, puppet('module uninstall jimmy-crakorn --version 0.5.x') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' (\e[0;36mv0.5.x\e[m) ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.5.1\e[0m) from /usr/share/puppet/modules
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ ! -d /usr/share/puppet/modules/crakorn ]'

step "Try to uninstall jimmy-crakorn v0.4.0 with `--version 0.5.x`"
on master, puppet('module uninstall jimmy-crakorn --version 0.5.x'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'jimmy-crakorn' (\e[0;36mv0.5.x\e[m) ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'jimmy-crakorn' (v0.5.x)
    STDERR>   No installed version of 'jimmy-crakorn' matches (v0.5.x)
    STDERR>     'jimmy-crakorn' (v0.4.0) is installed in /etc/puppet/modules\e[0m
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
