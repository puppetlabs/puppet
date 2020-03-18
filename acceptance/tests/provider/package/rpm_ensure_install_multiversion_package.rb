test_name "rpm should install packages with multiple versions" do
  confine :to, :platform => /redhat|centos|el|fedora/
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = "kernel-devel-puppet"
  repo_fixture_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures', 'el-repo')

  repo_content = <<-REPO
[local]
name=EL-$releasever - test packages
baseurl=file:///tmp/el-repo
enabled=1
gpgcheck=0
protect=1
REPO

  agents.each do |agent|
    initially_installed_versions = []
    scp_to(agent, repo_fixture_path, '/tmp')

    file_manifest = resource_manifest('file', '/etc/yum.repos.d/local.repo', ensure: 'present', content: repo_content)
    apply_manifest_on(agent, file_manifest)

    teardown do
      on(agent, 'rm -rf /tmp/el-repo')
      on(agent, 'rm -f /etc/yum.repos.d/local.repo')

      available_versions = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Available Packages/ d' | awk '{print $2}'").stdout
      initially_installed_versions.each do |version|
        if available_versions.include? version
          package_manifest = resource_manifest('package', package, ensure: version, install_only: true)
          apply_manifest_on(agent, package_manifest, :catch_failures => true)
        end
      end
    end

    step "Uninstall package versions for clean setup" do
      initially_installed_versions = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Installed Packages/ d' -e '/Available Packages/,$ d' | awk '{print $2}'").stdout.split("\n")

      package_manifest = resource_manifest('package', package, ensure: 'absent', install_only: true)
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        remaining_installed_versions = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Installed Packages/ d' -e '/Available Packages/,$ d' | awk '{print $2}'").stdout
        assert(remaining_installed_versions.empty?)
      end

      available_versions = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Available Packages/ d' | awk '{print $2}'").stdout.split("\n")
      if available_versions.size < 2
        skip_test "we need at least two package versions to perform the multiversion rpm test"
      end
    end

    step "Ensure oldest version of multiversion package is installed" do
      oldest_version = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Available Packages/ d' | head -1 | awk '{print $2}'").stdout.strip
      package_manifest = resource_manifest('package', package, ensure: oldest_version, install_only: true)
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        installed_version = on(agent, "rpm -q #{package}").stdout
        assert_match(oldest_version, installed_version)
      end
    end

    step "Ensure newest package multiversion package in installed" do
      newest_version = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Available Packages/ d' | tail -1 | awk '{print $2}'").stdout.strip
      package_manifest = resource_manifest('package', package, ensure: newest_version, install_only: true)
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        installed_version = on(agent, "rpm -q #{package}").stdout
        assert_match(newest_version, installed_version)
      end
    end

    step "Ensure rpm will uninstall multiversion package" do
      package_manifest = resource_manifest('package', package, ensure: 'absent', install_only: true)
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        remaining_installed_versions = on(agent, "yum --showduplicates list #{package} | sed -e '1,/Installed Packages/ d' -e '/Available Packages/,$ d' | awk '{print $2}'").stdout
        assert(remaining_installed_versions.empty?)
      end
    end
  end
end
