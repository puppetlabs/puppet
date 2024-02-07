test_name "pip provider should install, use install_options with latest, and uninstall" do
  confine :to, :template => /centos/
  tag 'audit:high'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = 'colorize'
  pip_command = 'pip'

  teardown do
    on(agent, "#{pip_command} uninstall #{package} --disable-pip-version-check --yes", :accept_all_exit_codes => true)
  end

  agents.each do |agent|
    step "Setup: Install EPEL Repository, Python and Pip" do
      package_present(agent, 'epel-release')
      if agent.platform =~ /el-8/
        package_present(agent, 'python2')
        package_present(agent, 'python2-pip')
        pip_command = 'pip2'
      else
        package_present(agent, 'python')
        package_present(agent, 'python-pip')
      end
    end

    step "Ensure presence of a pip package" do
      package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'pip' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, "#{pip_command} list --disable-pip-version-check").stdout
        assert_match(/#{package} \(/, list)
      end
      on(agent, "#{pip_command} uninstall #{package} --disable-pip-version-check --yes")
    end

    step "Install a pip package using version range" do
      package_manifest1 = resource_manifest('package', package, { ensure: '<=1.1.0', provider: 'pip' } )
      package_manifest2 = resource_manifest('package', package, { ensure: '<1.0.4',  provider: 'pip' } )

      # Make a fresh package install (with version lower than or equal to 1.1.0)
      apply_manifest_on(agent, package_manifest1, :expect_changes => true) do
        list = on(agent, "#{pip_command} list --disable-pip-version-check").stdout
        match = list.match(/#{package} \((.+)\)/)
        installed_version = match[1] if match
        assert_match(installed_version, '1.1.0')
      end

      # Reapply same manifest and expect no changes
      apply_manifest_on(agent, package_manifest1, :catch_changes => true)

      # Reinstall over existing package (with version lower than 1.0.4) and expect changes (to be 1.0.3)
      apply_manifest_on(agent, package_manifest2, :expect_changes => true) do
        list = on(agent, "#{pip_command} list --disable-pip-version-check").stdout
        match = list.match(/#{package} \((.+)\)/)
        installed_version = match[1] if match
        assert_match(installed_version, '1.0.3')
      end

      on(agent, "#{pip_command} uninstall #{package} --disable-pip-version-check --yes")
    end

    step "Ensure latest with pip uses install_options" do
      on(agent, "#{pip_command} install #{package} --disable-pip-version-check")
      package_manifest = resource_manifest('package', package, { ensure: 'latest', provider: 'pip', install_options: { '--index' => 'https://pypi.python.org/simple' } } )
      result = apply_manifest_on(agent, package_manifest, { :catch_failures => true, :debug => true } )
      assert_match(/--index=https:\/\/pypi.python.org\/simple/, result.stdout)
      on(agent, "#{pip_command} uninstall #{package} --disable-pip-version-check --yes")
    end

    step "Uninstall a pip package" do
      on(agent, "#{pip_command} install #{package} --disable-pip-version-check")
      package_manifest = resource_manifest('package', package, { ensure: 'absent', provider: 'pip' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, "#{pip_command} list --disable-pip-version-check").stdout
        refute_match(/#{package} \(/, list)
      end
    end
  end
end
