test_name "puppet module install (with existing module directory)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:unit',

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

default_moduledir = get_default_modulepath_for_host(master)

apply_manifest_on master, <<-PP
file {
  [
    '#{default_moduledir}/#{module_name}',
    '#{default_moduledir}/apache',
  ]: ensure => directory;
  '#{default_moduledir}/#{module_name}/metadata.json':
    content => '{
      "name": "not#{module_author}/#{module_name}",
      "version": "0.0.3",
      "source": "",
      "author": "not#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
  [
    '#{default_moduledir}/#{module_name}/extra.json',
    '#{default_moduledir}/apache/extra.json',
  ]: content => '';
}
PP

step "Try to install a module with a name collision"
module_name   = "nginx"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/Installation would overwrite #{default_moduledir}\/#{module_name}/, stderr,
        "Error of module collision was not displayed")
end
on master, "[ -f #{default_moduledir}/#{module_name}/extra.json ]"

step "Try to install a module with a path collision"
module_name   = "apache"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/Installation would overwrite #{default_moduledir}\/#{module_name}/, stderr,
        "Error of module collision was not displayed")
end
on master, "[ -f #{default_moduledir}/#{module_name}/extra.json ]"

step "Try to install a module with a dependency that has collides"
module_name   = "php"
on master, puppet("module install #{module_author}-#{module_name} --version 0.0.1"), :acceptable_exit_codes => [1] do
  assert_match(/Dependency .* would overwrite/, stderr,
        "Error of dependency collision was not displayed")
end
on master, "[ -f #{default_moduledir}/apache/extra.json ]"

step "Install a module with a name collision by using --force"
module_name   = "nginx"
on master, puppet("module install #{module_author}-#{module_name} --force"), :acceptable_exit_codes => [0] do
  assert_module_installed_ui(stdout, module_author, module_name)
end
on master, "[ ! -f #{default_moduledir}/#{module_name}/extra.json ]"

step "Install an module with a name collision by using --force"
module_name   = "apache"
on master, puppet("module install #{module_author}-#{module_name} --force"), :acceptable_exit_codes => [0] do
  assert_module_installed_ui(stdout, module_author, module_name)
end
on master, "[ ! -f #{default_moduledir}/#{module_name}/extra.json ]"
