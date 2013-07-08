test_name "puppet module install (with version)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_user = "puppetlabs"
module_name = "apache"
module_version = "0.0.3"
module_dependencies   = []

orig_installed_modules = get_installed_modules_for_hosts hosts

teardown do
  installed_modules = get_installed_modules_for_hosts hosts
  rm_installed_modules_from_hosts orig_installed_modules, installed_modules
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  step "  install module '#{module_user}-#{module_name}'"
  on(agent, puppet("module install --version \"<0.0.3\" #{module_user}-#{module_name}")) do
    /\(.*v(\d+\.\d+\.\d+)/ =~ stdout
    installed_version = Regexp.last_match[1]
    assert_match(/#{module_user}-#{module_name}/, stdout,
          "Module name not displayed during install")
    assert_match(/Notice: Installing -- do not interrupt/, stdout,
          "No installing notice displayed!")
    assert_equal( true, semver_cmp(installed_version, module_version) < 0,
          "installed version '#{installed_version}' of '#{module_name}' is not less than '#{module_version}'")
  end

  step "check for a '#{module_name}' manifest"
    on agent, "[ -f #{master['distmoduledir']}/#{module_name}/manifests/init.pp ]"

end
