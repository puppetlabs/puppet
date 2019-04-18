test_name "dpkg ensure held package should preserve version if package is allready installed"
confine :to, :platform => /debian-8-amd64/
require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::PackageUtils
extend Puppet::Acceptance::ManifestUtils

package = "openssl"

step "Ensure held should lock to specific installed version" do
  existing_installed_version = on(agent.name, "dpkg -s #{package} | sed -n -e 's/Version: //p'").stdout
  existing_installed_version.delete!(' ')

  package_manifest_held = resource_manifest('package', package, ensure: 'held')
  apply_manifest_on(agent, package_manifest_held) do
    installed_version = on(agent.name, "apt-cache policy #{package} | sed -n -e 's/Installed: //p'").stdout
    installed_version.delete!(' ')
    assert_match(existing_installed_version, installed_version)
  end
end