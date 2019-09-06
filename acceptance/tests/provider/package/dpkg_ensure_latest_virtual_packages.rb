test_name "dpkg ensure latest with allow_virtual set to true, the virtual package should detect and install a real package" do
  confine :to, :platform => /debian/
  tag 'audit:low'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils
  pkg = "rubygems"

  step "Ensure latest should install ruby instead of rubygems when allow_virtual is set to true" do
    package_manifest_with_allow_virtual = resource_manifest('package', pkg, ensure: 'latest', allow_virtual: true)
    apply_manifest_on(agent, package_manifest_with_allow_virtual)
    output = on(agent.name, "dpkg-query -W --showformat='${Status} ${Package} ${Version} [${Provides}]\n' ").output
    lines = output.split("\n")
    matched_line = lines.find { |package| package.match(/[\[ ](#{Regexp.escape(pkg)})[\],]/)}
    package_line_info = matched_line.split(" ")
    real_package_name = package_line_info[3]
    real_package_installed_version = package_line_info[4]
    installed_version = on(agent.name, "apt-cache policy #{real_package_name} | sed -n -e 's/Installed: //p'").stdout.strip
    assert_match(real_package_installed_version, installed_version)
  end

  step "Ensure latest should not install ruby package if it's allready installed and exit code should be 0" do
    package_manifest_with_allow_virtual = resource_manifest('package', pkg, ensure: 'latest', allow_virtual: true)
    exit_code = apply_manifest_on(agent, package_manifest_with_allow_virtual, :catch_changes => true, acceptable_exit_codes: [0,2]).exit_code
    assert_equal(exit_code, 0)
  end
end