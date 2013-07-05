test_name "puppet module install (agent)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

teardown do
  installed_modules = get_installed_modules_for_hosts hosts
  rm_installed_modules_from_hosts orig_installed_modules, installed_modules
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  step "install module '#{module_author}-#{module_name}'"
  on(agent, puppet("module install #{module_author}-#{module_name}")) do
    assert_match(/#{module_author}-#{module_name}/, stdout,
          "Module name not displayed during install")
    assert_match(/Notice: Installing -- do not interrupt/, stdout,
          "No installing notice displayed!")
  end

  step "check for a '#{module_name}' manifest"
    on(agent, "[ -f #{agent['distmoduledir']}/#{module_name}/manifests/init.pp ]")


end
