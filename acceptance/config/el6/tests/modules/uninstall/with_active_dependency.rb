test_name "puppet module uninstall (with active dependency)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
    '/etc/puppet/modules/appleseed',
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
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'

step "Try to uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'jimmy-crakorn'
    STDERR>   Other installed modules have dependencies on 'jimmy-crakorn' (v0.4.0)
    STDERR>     'jimmy/appleseed' (v1.1.0) requires 'jimmy-crakorn' (v0.4.0)
    STDERR>     Use `puppet module uninstall --force` to uninstall this module anyway\e[0m
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'

step "Try to uninstall the module jimmy-crakorn with a version range"
on master, puppet('module uninstall jimmy-crakorn --version 0.x'), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'jimmy-crakorn' (\e[0;36mv0.x\e[m) ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'jimmy-crakorn' (v0.x)
    STDERR>   Other installed modules have dependencies on 'jimmy-crakorn' (v0.4.0)
    STDERR>     'jimmy/appleseed' (v1.1.0) requires 'jimmy-crakorn' (v0.4.0)
    STDERR>     Use `puppet module uninstall --force` to uninstall this module anyway\e[0m
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'

step "Uninstall the module jimmy-crakorn forcefully"
on master, puppet('module uninstall jimmy-crakorn --force') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from /etc/puppet/modules
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/crakorn ]'
on master, '[ -d /etc/puppet/modules/appleseed ]'
