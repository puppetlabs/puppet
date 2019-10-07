test_name "Windows Package Provider" do
  confine :to, :platform => 'windows'

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/windows_utils'
  extend Puppet::Acceptance::WindowsUtils

  def package_manifest(name, params, installer_source)
    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "\"#{value_str}\"" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
package { '#{name}':
  source => '#{installer_source}',
  #{params_str}
}
MANIFEST
  end

  mock_package = {
    :name => "MockPackage"
  }

  agents.each do |agent|
    tmpdir = agent.tmpdir("mock_installer")
    installer_location = create_mock_package(agent, tmpdir, mock_package)

    step 'Verify that ensure = present installs the package' do
      apply_manifest_on(agent, package_manifest(mock_package[:name], {ensure: :present}, installer_location))
      assert(package_installed?(agent, mock_package[:name]), 'Package succesfully installed')
    end

    step 'Verify that ensure = absent removes the package' do
      apply_manifest_on(agent, package_manifest(mock_package[:name], {ensure: :absent}, installer_location))
      assert_equal(false, package_installed?(agent, mock_package[:name]), 'Package successfully Uninstalled')
    end

    tmpdir = agent.tmpdir("mock_installer")
    mock_package[:name] = "MockPackageWithFile"
    mock_package[:install_commands] = 'System.IO.File.ReadAllLines("install.txt");'
    installer_location = create_mock_package(agent, tmpdir, mock_package)

    # Since we didn't add the install.txt package the installation should fail with code 1004
    step 'Verify that ensure = present fails when an installer fails with a non-zero exit code' do
      apply_manifest_on(agent, package_manifest(mock_package[:name], {ensure: :present}, installer_location)) do |result|
        assert_match(/#{mock_package[:name]}/, result.stderr, 'Windows package provider did not fail when the package install failed')
      end
    end

    step 'Verify that ensure = present installs a package that requires additional resources' do
      create_remote_file(agent, "#{tmpdir}/install.txt", 'foobar')
      apply_manifest_on(agent, package_manifest(mock_package[:name], {ensure: :present}, installer_location))
      assert(package_installed?(agent, mock_package[:name]), 'Package succesfully installed')
    end

    step 'Verify that ensure = absent removes the package that required additional resources' do
      apply_manifest_on(agent, package_manifest(mock_package[:name], {ensure: :absent}, installer_location))
      assert_equal(false, package_installed?(agent, mock_package[:name]), 'Package successfully Uninstalled')
    end
  end

end
