test_name "apt can install range if package is not installed" do
  confine :to, :platform => /debian|ubuntu/
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = "helloworld"
  available_package_versions = ['1.0-1', '1.19-1', '2.0-1']
  repo_fixture_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures', 'debian-repo')

  agents.each do |agent|
    scp_to(agent, repo_fixture_path, '/tmp')

    file_manifest = resource_manifest('file', '/etc/apt/sources.list.d/tmp.list', ensure: 'present', content: 'deb [trusted=yes] file:/tmp/debian-repo ./')
    apply_manifest_on(agent, file_manifest)

    on(agent, 'apt-get update')

    teardown do
      package_absent(agent, package, '--force-yes')
      file_manifest = resource_manifest('file', '/etc/apt/sources.list.d/tmp.list', ensure: 'absent')
      apply_manifest_on(agent, file_manifest)
      on(agent, 'rm -rf /tmp/debian-repo')
      on(agent, 'apt-get update')
    end

    step "Ensure that package is installed first if not present" do
      package_manifest = resource_manifest('package', package, ensure: "<=#{available_package_versions[1]}")
      apply_manifest_on(agent, package_manifest)
      installed_package_version = on(agent.name, "apt-cache policy #{package} | sed -n -e 's/Installed: //p'").stdout
      assert_match(available_package_versions[1], installed_package_version)
    end

    step "Ensure that package is updated" do
      package_manifest = resource_manifest('package', package, ensure: ">#{available_package_versions[1]}")
      apply_manifest_on(agent, package_manifest)
      installed_package_version = on(agent.name, "apt-cache policy #{package} | sed -n -e 's/Installed: //p'").stdout
      assert_match(available_package_versions[2], installed_package_version)
    end
  end
end
