test_name "puppet module upgrade should succeed if installed version is an invalid semver"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

skip_test "Skip until PUP-3093 is resolved"

confine :except, :platform => 'solaris-10'

require 'json'

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = ["stdlub"]
module_version = "1.6.0"

orig_installed_modules = get_installed_modules_for_hosts(hosts)
teardown do
  rm_installed_modules_from_hosts(orig_installed_modules, get_installed_modules_for_hosts(hosts))
end

agents.each do |agent|
  if agent['platform'] =~ /windows/
    p = on(agent, 'cygpath -uF 35').stdout.chomp
    agent['distmoduledir'] = agent['distmoduledir'].sub('`cygpath -smF 35`', p)
  end

  step "Install older version of module" do
    stub_forge_on(agent)
    on(agent, puppet("module install #{module_author}-#{module_name} --version #{module_version}"))
  end

  step "Change 'version' to invalid value in metadata.json" do
    metafile = "#{agent['distmoduledir']}/#{module_name}/metadata.json"
    if on(agent, "test -f #{metafile}", :acceptable_exit_codes => [0,1]).exit_code == 1
      metafile = "#{agent['distmoduledir']}/#{module_name}/Modulefile"
      on(agent, "test -f #{metafile}")
    end
    puts metafile
    metadata = on(agent, "cat #{metafile}").stdout
    m = JSON.parse(metadata)
    m['version'] = 'hello.world'
    on(agent, "rm -f #{agent['distmoduledir']}/#{other_module_name}/metadata.json")
    create_remote_file(agent, "#{agent['distmoduledir']}/#{module_name}/metadata.json", JSON.dump(m))
  end

  step "Upgrade module should succeed and warn that the version is invalid" do
    on(agent, puppet("module upgrade #{module_author}-#{module_name}")) do |res|
      assert_match(/Warning: #{module_name} .* has an invalid version number/, res.stderr, "Proper warning not displayed")
    end
  end

end
