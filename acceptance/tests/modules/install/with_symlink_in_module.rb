test_name "puppet module install with symlink in module should warn"

# skipping solaris until PE-5766
confine :except, :platform => [ 'windows', 'solaris' ]

require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "containssymlink"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

agents.each do |agent|
  stub_forge_on(agent)

  step "install module '#{module_author}-#{module_name}'" do
    on(agent, puppet("module install #{module_author}-#{module_name}")) do |res|
      assert_module_installed_ui(res.stdout, module_author, module_name)
      assert_match(/Warning:.*[Ss]ymlinks in modules are unsupported/, res.stderr)
    end
  end
end
