test_name "dnfmodule is versionable" do
  confine :to, :platform => /el-8-x86_64/  # only el/centos 8 have the appstream repo
  tag 'audit:high'

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

  step "Ensure we get the newer version by default" do
    apply_manifest_on(agent, resource_manifest('package', package, ensure: 'present', provider: 'dnfmodule'))
    on(agent, 'postgres --version') do |version|
      assert_match('postgres (PostgreSQL) 10', version.stdout, 'package version not correct')
    end
  end

  step "Ensure we get a specific version if we want it" do
    apply_manifest_on(agent, resource_manifest('package', package, ensure: '9.6', provider: 'dnfmodule'))
    on(agent, 'postgres --version') do |version|
      assert_match('postgres (PostgreSQL) 9.6', version.stdout, 'package version not correct')
    end
  end
end
