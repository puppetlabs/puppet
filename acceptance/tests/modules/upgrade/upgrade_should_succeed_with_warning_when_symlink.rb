test_name "puppet module upgrade should succeed with warning when module contains symlink"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

confine :except, :platform => ['windows', 'solaris-10']

module_author = "pmtacceptance"
module_name   = "containssymlink"
module_version   = "1.0.0"

orig_installed_modules = get_installed_modules_for_hosts(hosts)
teardown do
  rm_installed_modules_from_hosts(orig_installed_modules, get_installed_modules_for_hosts(hosts))
end

agents.each do |agent|

  pending_test("pending resolution of PE-5766 for solaris-11") if agent['platform'] =~ /solaris-11/

  step 'Install module containing symlink' do
    stub_forge_on(agent)
    tmpdir = agent.tmpdir(module_name)
    download = "#{tmpdir}/#{module_name}.tar.gz"
    curl_on(agent, "-o #{download} https://forgeapi.puppetlabs.com/v3/files/#{module_author}-#{module_name}-#{module_version}.tar.gz")
    on(agent, "(cd #{agent['distmoduledir']} ; tar -vxzf #{download}; mv #{module_author}-#{module_name}-#{module_version} #{module_name})")
  end

  step 'Upgrade module containing symlink' do
    on(agent, puppet("module upgrade #{module_author}-#{module_name}")) do |res|
      fail_test('Proper failure message not displayed') unless res.stderr.include? 'Symlinks in modules are unsupported'
    end
  end

end
