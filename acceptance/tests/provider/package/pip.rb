test_name "pip provider should install, use install_options with latest, and uninstall" do
  confine :to, :template => /centos/
  tag 'audit:low'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = 'colorize'

  agents.each do |agent|
    pip_command = 'pip'
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

    step "Install a pip package" do
      package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'pip' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, "#{pip_command} list --disable-pip-version-check").stdout
        assert_match(/#{package} \(/, list)
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
        assert_no_match(/#{package} \(/, list)
      end
    end
  end
end
