test_name "puppet module upgrade with lastest version already installed should succeed with notice"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

confine :except, :platform => 'solaris-10'

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = ["stdlub"]

orig_installed_modules = get_installed_modules_for_hosts(hosts)
teardown do
  rm_installed_modules_from_hosts(orig_installed_modules, get_installed_modules_for_hosts(hosts))
end

agents.each do |agent|

  step "Install module" do
    stub_forge_on(agent)
    on(agent, puppet("module install #{module_author}-#{module_name}"))
  end

  step "Upgrade module should succeed with notice that the lastest is already installed" do
    on(agent, puppet("module upgrade #{module_author}-#{module_name}")) do |res|
      assert_match(/version is already the latest version/, res.stdout, "Proper notice not displayed")
    end
  end

end
