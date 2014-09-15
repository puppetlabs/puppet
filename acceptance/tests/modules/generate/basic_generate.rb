test_name "puppet module generate (agent)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

agents.each do |agent|

  teardown do
    on agent,"rm -fr '#{module_author}-#{module_name}'", :acceptable_exit_codes => (0..254)
  end

  step "Generate #{module_author}-#{module_name} module"
  on agent, puppet("module generate #{module_author}-#{module_name} --skip-interview")

  step "Check for #{module_name} scaffolding"
  on agent,"test -f #{module_author}-#{module_name}/manifests/init.pp"

end
