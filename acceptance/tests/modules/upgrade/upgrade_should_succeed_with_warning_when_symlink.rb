test_name "puppet module upgrade should succeed with warning when module contains symlink"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

hosts.each do |host|
  pending_test "pending requiring forge certs on solaris and PE-5766" if host['platform'] =~ /solaris/
end

module_author = "pmtacceptance"
module_name   = "containssymlink"
module_version   = "1.0.0"

orig_installed_modules = get_installed_modules_for_hosts(hosts)
teardown do
  rm_installed_modules_from_hosts(orig_installed_modules, get_installed_modules_for_hosts(hosts))
end

agents.each do |agent|
  step 'ensure moduledir exists'
  on(agent, "mkdir -p #{agent['distmoduledir']}")

  step 'Install module containing symlink' do
    stub_forge_on(agent)
    tmpdir = agent.tmpdir(module_name)
    download = "#{tmpdir}/#{module_name}.tar.gz"
    curl_on(agent, "-o #{download} https://forgeapi.puppetlabs.com/v3/files/#{module_author}-#{module_name}-#{module_version}.tar.gz")
    on(agent, "cd #{tmpdir}; tar -vxzf #{module_name}.tar.gz; mv #{module_author}-#{module_name}-#{module_version} #{agent['distmoduledir']}/#{module_name}")
  end

  step 'Upgrade module containing symlink' do
    on(agent, puppet("module upgrade --ignore-changes #{module_author}-#{module_name}")) do |res|
      if agent['platform'] =~ /windows/
        fail_test('Proper warning displayed! Fix this test after pup-3789.') if res.stderr.include? 'Symlinks in modules are unsupported'
        pending_test "Pending partial test on windows until pup-3789"
      else
        fail_test('Proper failure message not displayed') unless res.stderr.include? 'Symlinks in modules are unsupported'
      end
    end
  end
end
