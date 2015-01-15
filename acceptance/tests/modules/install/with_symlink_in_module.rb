test_name "puppet module install with symlink in module should warn"

# skipping solaris until PE-5766
hosts.each do |host|
  skip_test "skip test requiring forge certs on solaris and until PE-5766" if host['platform'] =~ /solaris/
end

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
      if agent['platform'] =~ /windows/
        skip_test "skip warning assertion on windows until pup-3789 (windows doesn't warn on PMT installs with symlinks)"
      else
        assert_match(/Warning:.*[Ss]ymlinks in modules are unsupported/, res.stderr)
      end
    end
  end
end
