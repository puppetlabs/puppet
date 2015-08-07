test_name "puppet module uninstall (with module installed)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "jimmy"
module_name   = "crakorn"
module_dependencies = []

default_moduledir = get_default_modulepath_for_host(master)
secondary_moduledir = get_nondefault_modulepath_for_host(master)

skip_test "no secondary moduledir available on master" if secondary_moduledir.empty?

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '#{default_moduledir}/#{module_name}',
    '#{secondary_moduledir}/#{module_name}',
    '#{secondary_moduledir}/appleseed',
  ]: ensure => directory;
  '#{default_moduledir}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}/#{module_name}",
      "version": "0.4.0",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
  '#{secondary_moduledir}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}/#{module_name}",
      "version": "0.5.1",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
  '#{secondary_moduledir}/appleseed/metadata.json':
    content => '{
      "name": "#{module_author}/appleseed",
      "version": "0.4.0",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
}
PP

step "Uninstall #{module_author}-#{module_name} version 0.5.x"
on master, puppet("module uninstall #{module_author}-#{module_name} --version 0.5.x") do
  assert_match(/Removed '#{module_author}-#{module_name}'/, stdout,
        "Notice that module was uninstalled was not displayed")
end
on master, "[ -d #{default_moduledir}/#{module_name} ]"
on master, "[ ! -d #{secondary_moduledir}/#{module_name} ]"

step "Try to uninstall #{module_author}-#{module_name} v0.4.0 with `--version 0.5.x`"
on master, puppet("module uninstall #{module_author}-#{module_name} --version 0.5.x"), :acceptable_exit_codes => [1] do
  assert_match(/Could not uninstall module '#{module_author}-#{module_name}'/, stderr,
        "Error that module could not be uninstalled was not displayed")
  assert_match(/No installed version of '#{module_author}-#{module_name}' matches/, stderr,
        "Error that module version could not be found was not displayed")
end
on master, "[ -d #{default_moduledir}/#{module_name} ]"

module_name = 'appleseed'
step "Try to uninstall #{module_author}-#{module_name} v0.4.0 with `--version >9.9.9`"
on master, puppet("module uninstall #{module_author}-#{module_name} --version \">9.9.9\""), :acceptable_exit_codes => [1] do
  assert_match(/Could not uninstall module '#{module_author}-#{module_name}'/, stderr,
        "Error that module could not be uninstalled was not displayed")
  assert_match(/No installed version of '#{module_author}-#{module_name}' matches/, stderr,
        "Error that module version could not be found was not displayed")
end
on master, "[ -d #{secondary_moduledir}/#{module_name} ]"

step "Uninstall #{module_author}-#{module_name} v0.4.0 with `--version >0.0.0`"
on master, puppet("module uninstall #{module_author}-#{module_name} --version \">0.0.0\"") do
  assert_match(/Removed '#{module_author}-#{module_name}'/, stdout,
        "Notice that module was uninstalled was not displayed")
end
on master, "[ ! -d #{secondary_moduledir}/#{module_name} ]"
