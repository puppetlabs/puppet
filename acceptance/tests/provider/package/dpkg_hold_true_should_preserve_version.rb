test_name "dpkg ensure hold package should preserve version if package is already installed" do
  confine :to, :platform => /debian-9-amd64/
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = "openssl"

  step "Ensure hold should lock to specific installed version" do
    existing_installed_version = on(agent.name, "dpkg -s #{package} | sed -n -e 's/Version: //p'").stdout
    existing_installed_version.delete!(' ')

    package_manifest_hold = resource_manifest('package', package, mark: "hold")
    apply_manifest_on(agent, package_manifest_hold) do
      installed_version = on(agent.name, "apt-cache policy #{package} | sed -n -e 's/Installed: //p'").stdout
      installed_version.delete!(' ')
      assert_match(existing_installed_version, installed_version)
    end
  end
end
