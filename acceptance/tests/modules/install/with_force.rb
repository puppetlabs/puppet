test_name "puppet module install (agent)"

module_user = "pmtacceptance"
module_name = "nginx"

teardown do
  agents.each do |agent|
    result = on agent, puppet("config print modulepath")
    result.stdout.split(':').each do |module_path|
      if ! module_path.include? "/opt"
        on agent, "[ -d #{module_path} ] && rm -fr #{module_path}/* || true"
      end
    end
  end
end

agents.each do |agent|
  step 'setup'
  stub_forge_on(agent)

  step "install module '#{module_user}-#{module_name}'"
  on(agent, puppet("module install #{module_user}-#{module_name}")) do
    assert_match(/#{module_user}-#{module_name}/, stdout,
          "Module name not displayed during install")
    assert_match(/Notice: Installing -- do not interrupt/, stdout,
          "No installing notice displayed!")
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


  step "install module '#{module_user}-#{module_name}' again with --force"
  on(agent, puppet("module install --force #{module_user}-#{module_name}")) do
    assert_match(/#{module_user}-#{module_name}/, stdout,
          "Module name not displayed during install")
    assert_match(/Notice: Installing -- do not interrupt/, stdout,
          "No installing notice displayed!")
  end

end
