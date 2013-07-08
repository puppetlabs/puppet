test_name "puppet module install (nonexistent module)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nonexistent"
module_dependencies  = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Try to install a non-existent module"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_match(/#{module_author}\/#{module_name} not found/, stderr,
        "Error that module was not found was not displayed")
end

step "Try to install a non-existent module (JSON rendering)"
on master, puppet("module --render-as json install #{module_author}-#{module_name}") do
  require 'json'
  str  = stdout.lines.to_a.last
  json = JSON.parse(str)

  oneline_expectation   = %[Could not execute operation for '#{module_author}/#{module_name}'. Detail: Module #{module_author}/#{module_name} not found / 410 Gone.]
  multiline_expectation = <<-OUTPUT.chomp
Could not execute operation for '#{module_author}/#{module_name}'
  The server being queried was https://forge.puppetlabs.com
  The HTTP response we received was '410 Gone'
  The message we received said 'Module #{module_author}/#{module_name} not found'
    Check the author and module names are correct.
OUTPUT


  assert_equal nil,                         json['module_version']
  assert_equal "#{module_author}-#{module_name}", json['module_name']
  assert_equal 'failure',                   json['result']
  assert_equal master['distmoduledir'],     json['install_dir']
  assert_equal multiline_expectation,       json['error']['multiline']
  assert_equal oneline_expectation,         json['error']['oneline']
end

