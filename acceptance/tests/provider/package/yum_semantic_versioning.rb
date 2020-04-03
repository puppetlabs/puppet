test_name "yum provider should use semantic versioning for ensuring desired version" do
  confine :to, :platform => /el-7/
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = 'yum-utils'

  lower_package_version = '1.1.31-34.el7'
  middle_package_version = '1.1.31-42.el7'
  higher_package_version = '1.1.31-45.el7'

  agents.each do |agent|
    yum_command = 'yum'

    step "Setup: Skip test if box already has the package installed" do
      on(agent, "rpm -q #{package}", :acceptable_exit_codes => [1,0]) do |result|
        skip_test "package #{package} already installed on this box" unless result.output =~ /package #{package} is not installed/
      end
    end

    step "Setup: Skip test if package versions are not available" do
      on(agent, "yum list #{package} --showduplicates", :acceptable_exit_codes => [1,0]) do |result|
        versions_available = [lower_package_version, middle_package_version, higher_package_version].all? {
          |needed_versions| result.output.include? needed_versions }
        skip_test "package #{package} versions not available on the box" unless versions_available
      end
    end

    step "Using semantic versioning to downgrade to a desired version <= X" do
      on(agent, "#{yum_command} install #{package} -y")
      package_manifest = resource_manifest('package', package, { ensure: "<=#{lower_package_version}", provider: 'yum' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        installed_version = on(agent, "rpm -q #{package}").stdout
        assert_match(/#{lower_package_version}/, installed_version)
      end
      # idempotency test
      package_manifest = resource_manifest('package', package, { ensure: "<=#{lower_package_version}", provider: 'yum' } )
      apply_manifest_on(agent, package_manifest, :catch_changes => true)
      on(agent, "#{yum_command} remove #{package} -y")
    end

    step "Using semantic versioning to ensure a version >X <=Y" do
      on(agent, "#{yum_command} install #{package} -y")
      package_manifest = resource_manifest('package', package, { ensure: ">#{lower_package_version} <=#{higher_package_version}", provider: 'yum' } )
      apply_manifest_on(agent, package_manifest) do
        installed_version = on(agent, "rpm -q #{package}").stdout
        assert_match(/#{higher_package_version}/, installed_version)
      end
      on(agent, "#{yum_command} remove #{package} -y")
    end

    step "Using semantic versioning to install a version >X <Y" do
      package_manifest = resource_manifest('package', package, { ensure: ">#{lower_package_version} <#{higher_package_version}", provider: 'yum' } )
      # installing a version >X <Y will install the highet version in between
      apply_manifest_on(agent, package_manifest) do
        installed_version = on(agent, "rpm -q #{package}").stdout
        assert_match(/#{middle_package_version}/, installed_version)
      end
      on(agent, "#{yum_command} remove #{package} -y")
    end

  end
end
