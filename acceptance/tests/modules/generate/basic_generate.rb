test_name "puppet module generate (agent)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:medium',
    'audit:acceptance'

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

agents.each do |agent|

  step "Generate #{module_author}-#{module_name} module"
  on agent, puppet("module generate #{module_author}-#{module_name} --skip-interview")

  step "Check for #{module_name} scaffolding"
  on agent,"test -f #{module_name}/manifests/init.pp"

  step "Clean up"
  on agent,"rm -fr #{module_name}"
end
