test_name "puppet module install (nonexistent module)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

module_author = "pmtacceptance"
module_name   = "nonexistent"
module_dependencies  = []

default_moduledir = get_default_modulepath_for_host(master)

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Try to install a non-existent module"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/could not install '#{module_author}-#{module_name}'/i, stderr,
      "Error that module could not be installed was not displayed")

  assert_match(/no releases are available from/i, stderr,
      "Error that no releases were found was not displayed")
end

step "Try to install a non-existent module (JSON rendering)"
on master, puppet("module --render-as json install #{module_author}-#{module_name}") do
  require 'json'
  str  = stdout.lines.to_a.last
  json = JSON.parse(str)

  oneline_expectation   = /could not install '#{module_author}-#{module_name}'; no releases are available from/i
  multiline_expectation = /could not install '#{module_author}-#{module_name}'.*no releases are available from.*have at least one published release.*\z/im

  assert_equal 'failure', json['result']
  assert_equal "#{module_author}-#{module_name}", json['module_name']
  assert_equal '>= 0.0.0', json['module_version']
  assert_equal default_moduledir, json['install_dir']
  assert_match oneline_expectation, json['error']['oneline']
  assert_match multiline_expectation, json['error']['multiline']
end
