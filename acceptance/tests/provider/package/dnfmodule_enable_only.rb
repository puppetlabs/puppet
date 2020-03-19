test_name "dnfmodule can change flavors" do
  confine :to, :platform => /el-8-x86_64/  # only el/centos 8 have the appstream repo
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  without_profile = '389-ds'
  with_profile = 'swig'

  agents.each do |agent|
    skip_test('appstream repo not present') unless on(agent, 'dnf repolist').stdout.include?('appstream')
    teardown do
      apply_manifest_on(agent, resource_manifest('package', without_profile, ensure: 'absent', provider: 'dnfmodule'))
      apply_manifest_on(agent, resource_manifest('package', with_profile, ensure: 'absent', provider: 'dnfmodule'))
    end
  end

  step "Enable module with no default profile: #{without_profile}" do
    apply_manifest_on(agent, resource_manifest('package', without_profile, ensure: 'present', provider: 'dnfmodule'), expect_changes: true)
    on(agent, "dnf module list --enabled | grep #{without_profile}")
  end

  step "Ensure idempotency for: #{without_profile}" do
    apply_manifest_on(agent, resource_manifest('package', without_profile, ensure: 'present', provider: 'dnfmodule'), catch_changes: true)
  end

  step "Enable module with a profile: #{with_profile}" do
    apply_manifest_on(agent, resource_manifest('package', with_profile, ensure: 'present', enable_only: true, provider: 'dnfmodule'), expect_changes: true)
    on(agent, "dnf module list --enabled | grep #{with_profile}")
  end

  step "Ensure idempotency for: #{with_profile}" do
    apply_manifest_on(agent, resource_manifest('package', with_profile, ensure: 'present', enable_only: true, provider: 'dnfmodule'), catch_changes: true)
  end

  step "Install a flavor for: #{with_profile}" do
    apply_manifest_on(agent, resource_manifest('package', with_profile, ensure: 'present', flavor: 'common', provider: 'dnfmodule'), expect_changes: true)
    on(agent, "dnf module list --installed | grep #{with_profile}")
  end
end
