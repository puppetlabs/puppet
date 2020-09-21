test_name "puppet_gem provider uses Puppet's ruby" do
  tag 'audit:high'
  confine :to, platform: /windows|redhat|ubuntu/

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::ManifestUtils

  package = 'colorize'

  agents.each do |agent|
    teardown do
      on(agent, puppet("resource package #{package} ensure=absent provider=puppet_gem"))
    end

    step "Install a gem" do
      package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'puppet_gem' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do

        puppet_gem_list = on(agent, "#{gem_command(agent)} list").stdout
        assert_match(/#{package} \(/, puppet_gem_list)
      end
    end

    step "Uninstall a gem" do
      package_manifest = resource_manifest('package', package, { ensure: 'absent', provider: 'puppet_gem' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        puppet_gem_list = on(agent, "#{gem_command(agent)} list").stdout
        assert_no_match(/#{package} \(/, puppet_gem_list)
      end
    end
  end
end
