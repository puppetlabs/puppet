test_name "dnfmodule can change flavors" do
  confine :to, :platform => /el-8-x86_64/  # only el/centos 8 have the appstream repo
  tag 'audit:low'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = "postgresql"

  agents.each do |agent|
    skip_test('appstream repo not present') unless on(agent, 'dnf repolist').stdout.include?('appstream')
    teardown do
      apply_manifest_on(agent, resource_manifest('package', package, ensure: 'absent', provider: 'dnfmodule'))
    end
  end

  step "Install the client #{package} flavor" do
    apply_manifest_on(agent, resource_manifest('package', package, ensure: 'present', flavor: 'client', provider: 'dnfmodule'))
    on(agent, "dnf module list --installed | grep #{package} | sed -E 's/\\[d\\] //g'") do |output|
      assert_match('client [i]', output.stdout, 'installed flavor not correct')
    end
  end

  step "Install the server #{package} flavor" do
    apply_manifest_on(agent, resource_manifest('package', package, ensure: 'present', flavor: 'server', provider: 'dnfmodule'))
    on(agent, "dnf module list --installed | grep #{package} | sed -E 's/\\[d\\] //g'") do |output|
      assert_match('server [i]', output.stdout, 'installed flavor not correct')
    end
  end
end
