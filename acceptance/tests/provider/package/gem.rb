test_name "gem provider should install and uninstall" do
  confine :to, :template => /centos-7-x86_64|redhat-7-x86_64/
  tag 'audit:low'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = 'colorize'

  agents.each do |agent|
    # On a Linux host with only the 'agent' role, the puppet command fails when another Ruby is installed earlier in the PATH:
    #
    # [root@agent ~]# env PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/opt/puppetlabs/bin" puppet apply  -e ' notify { "Hello": }'
    # Activating bundler (2.0.2) failed:
    # Could not find 'bundler' (= 2.0.2) among 5 total gem(s)
    # To install the version of bundler this project requires, run `gem install bundler -v '2.0.2'`
    #
    # Magically, the puppet command succeeds on a Linux host with both the 'master' and 'agent' roles.
    #
    # Puppet's Ruby makes a fine target. Unfortunately, it's first in the PATH on Windows: PUP-6134.
    # Also, privatebindir isn't a directory on Windows, it's a PATH:
    # https://github.com/puppetlabs/beaker-puppet/blob/master/lib/beaker-puppet/install_utils/aio_defaults.rb
    #
    # These tests depend upon testing being confined to /centos-7-x86_64|redhat-7-x86_64/.
    if agent['roles'].include?('master')
      original_path = agent.get_env_var('PATH')

      # https://github.com/puppetlabs/puppet-agent/blob/master/resources/files/puppet-agent.sh
      puppet_agent_sh_path = '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/opt/puppetlabs/bin'

      system_gem_command = '/usr/bin/gem'

      teardown do
        step "Teardown: Uninstall System Ruby, and reset PATH" do
          package_absent(agent, 'ruby')
          agent.add_env_var('PATH', original_path)
        end
      end
      
      step "Setup: Install System Ruby, and set PATH to place System Ruby ahead of Puppet Ruby" do
        package_present(agent, 'ruby')
        agent.add_env_var('PATH', puppet_agent_sh_path)
      end
    
      step "Install a gem package in System Ruby" do
        package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'gem' } )
        apply_manifest_on(agent, package_manifest, :catch_failures => true) do
          list = on(agent, "#{system_gem_command} list").stdout
          assert_match(/#{package} \(/, list)
        end
        on(agent, "#{system_gem_command} uninstall #{package}")
      end

      step "Uninstall a gem package in System Ruby" do
        on(agent, "/usr/bin/gem install #{package}")
        package_manifest = resource_manifest('package', package, { ensure: 'absent', provider: 'gem' } )
        apply_manifest_on(agent, package_manifest, :catch_failures => true) do
          list = on(agent, "#{system_gem_command} list").stdout
          assert_no_match(/#{package} \(/, list)
        end
        on(agent, "#{system_gem_command} uninstall #{package}")
      end
      
      step "Uninstall System Ruby, and reset PATH" do
        package_absent(agent, 'ruby')
        agent.add_env_var('PATH', original_path)
      end
    end

    puppet_gem_command = "#{agent['privatebindir']}/gem"

    step "Install a gem package with a target command" do
      package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'gem', command: puppet_gem_command } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, "#{puppet_gem_command} list").stdout
        assert_match(/#{package} \(/, list)
      end
      on(agent, "#{puppet_gem_command} uninstall #{package}")
    end

    step "Uninstall a gem package with a target command" do
      on(agent, "#{puppet_gem_command} install #{package}")
      package_manifest = resource_manifest('package', package, { ensure: 'absent', provider: 'gem', command: puppet_gem_command } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, "#{puppet_gem_command} list").stdout
        assert_no_match(/#{package} \(/, list)
      end
      on(agent, "#{puppet_gem_command} uninstall #{package}")
    end
  end
end
