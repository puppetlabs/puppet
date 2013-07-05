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

def semver_to_i ( semver )
  # semver assumed to be in format <major>.<minor>.<patch>
  # calculation assumes that each segment is < 100
  tmp = semver.split('.')
  tmp[0].to_i * 10000 + tmp[1].to_i * 100 + tmp[2].to_i
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
    assert_equal( true, semver_to_i(installed_version) < semver_to_i(module_version),
          "installed version '#{installed_version}' of '#{module_name}' is not less than '#{module_version}'")
  end

  step "check for a '#{module_name}' manifest"
  manifest_found = false
  result = on agent, puppet("config print modulepath")
  result.stdout.split(':').each do |module_path|
    module_path = module_path.strip
    if ! module_path.include? "/opt"
      r = on(agent, "[ -f #{module_path}/#{module_name}/manifests/init.pp ]", :acceptable_error_codes => [0,1])
      if r.exit_code == 0:
        manifest_found = true
        break
      end
    end
  end
  assert_equal( true, manifest_found, "Manifest file not found for '#{module_name}' module")

end
