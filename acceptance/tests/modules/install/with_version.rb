test_name "puppet module install (with version)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name = "java"
module_version = "1.7.0"
module_dependencies   = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  step "  install module '#{module_author}-#{module_name}'"

  opts ||= Hash.new
  opts['ENV']=Command::DEFAULT_GIT_ENV
  command = agent['platform'] =~ /windows/ ?
    Command.new("'puppet module install --version \"<#{module_version}\" #{module_author}-#{module_name}'", [], opts) :
    puppet("module install --version \"<#{module_version}\" #{module_author}-#{module_name}")

  on(agent, command) do
    assert_module_installed_ui(stdout, module_author, module_name, module_version, '<')
  end
  assert_module_installed_on_disk(agent, module_name)
end
