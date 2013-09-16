test_name "puppet module install (with version)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "puppetlabs"
module_name = "apache"
module_version = "0.0.3"
module_dependencies   = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  distmoduledir = on(agent, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

  step "  install module '#{module_author}-#{module_name}'"

  command = agent['platform'] =~ /windows/ ?
    Command.new("cmd.exe /c 'puppet module install --version \"<#{module_version}\" #{module_author}-#{module_name}'") :
    puppet("module install --version \"<#{module_version}\" #{module_author}-#{module_name}")

  on(agent, command) do
    assert_module_installed_ui(stdout, module_author, module_name, module_version, '<')
  end
  assert_module_installed_on_disk(agent, distmoduledir, module_name)
end
