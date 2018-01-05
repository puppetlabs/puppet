test_name "puppet module install (agent)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:delete'     # This behavior is validated with other tests in this suite

confine :except, :platform => /centos-4|el-4/ # PUP-5226

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

agents.each do |agent|

  if on(agent, facter("fips_enabled")).stdout =~ /true/
    puts "Module build, loading and installing not supported on fips enabled platforms"
    next
  end

  step 'setup'
  stub_forge_on(agent)

  step "install module '#{module_author}-#{module_name}'"
  on(agent, puppet("module install #{module_author}-#{module_name}")) do
    assert_module_installed_ui(stdout, module_author, module_name)
  end
  assert_module_installed_on_disk(agent, module_name)
end
