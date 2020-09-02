test_name "puppetserver_gem provider should install and uninstall" do
  tag 'audit:high',
      'server'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  skip_test 'puppetserver_gem is only suitable on server nodes' unless master

  package = 'world_airports'

  teardown do
    # Ensure the gem is uninstalled if anything goes wrong
    # TODO maybe execute this only if something fails, as it takes time
    on(master, "puppetserver gem uninstall #{package}")
  end

  step "Installing a gem executes without error" do
    package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'puppetserver_gem' } )
    apply_manifest_on(master, package_manifest, catch_failures: true) do
      list = on(master, "puppetserver gem list").stdout
      assert_match(/#{package} \(/, list)
    end

    # Run again for idempotency
    apply_manifest_on(master, package_manifest, catch_changes: true)
  end

  step "Uninstalling a gem executes without error" do
    package_manifest = resource_manifest('package', package, { ensure: 'absent', provider: 'puppetserver_gem' } )
    apply_manifest_on(master, package_manifest, catch_failures: true) do
      list = on(master, "puppetserver gem list").stdout
      assert_no_match(/#{package} \(/, list)
    end
  end
end
