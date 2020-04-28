test_name "zypper can install range if package is not installed" do
  confine :to, :platform => /sles/
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = "helloworld"
  available_package_versions = ['1.0-2', '1.19-2', '2.0-2']
  repo_fixture_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures', 'sles-repo')
  repo_content = <<-REPO
[local]
name=local - test packages
baseurl=file:///tmp/sles-repo
enabled=1
gpgcheck=0
REPO

  agents.each do |agent|
    scp_to(agent, repo_fixture_path, '/tmp')

    file_manifest = resource_manifest('file', '/etc/zypp/repos.d/local.repo', ensure: 'present', content: repo_content)
    apply_manifest_on(agent, file_manifest)

    teardown do
      package_absent(agent, package, '--force-yes')
      file_manifest = resource_manifest('file', '/etc/zypp/repos.d/local.repo', ensure: 'absent')
      apply_manifest_on(agent, file_manifest)
      on(agent, 'rm -rf /tmp/sles-repo')
    end

    step "Ensure that package is installed first if not present" do
      package_manifest = resource_manifest('package', package, ensure: "<=#{available_package_versions[1]}")
      apply_manifest_on(agent, package_manifest)
      installed_package_version = on(agent, "rpm -q #{package}").stdout
      assert_match(available_package_versions[1], installed_package_version)
    end

    step "Ensure that package is updated" do
      package_manifest = resource_manifest('package', package, ensure: ">#{available_package_versions[1]}")
      apply_manifest_on(agent, package_manifest)
      installed_package_version = on(agent, "rpm -q #{package}").stdout
      assert_match(available_package_versions[2], installed_package_version)
    end
  end
end
