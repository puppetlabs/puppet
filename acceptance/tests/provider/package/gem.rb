test_name "gem provider should install and uninstall" do
  confine :to, :template => /centos-7-x86_64|windows-2012r2-64/
  tag 'audit:low'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  package = 'colorize'

  # https://github.com/puppetlabs/puppet-agent/blob/master/resources/files/puppet-agent.sh
  puppet_agent_sh_path = '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/opt/puppetlabs/bin'

  wins_ruby_version = '2.4.6-1-x64'
  wins_ruby_installer_url = "https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-#{wins_ruby_version}/rubyinstaller-#{wins_ruby_version}.exe"
  wins_ruby_installer_exe = "rubyinstaller-#{wins_ruby_version}-x64.exe"
  wins_enable_tls12  = "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12"
  wins_download_file = "(New-Object System.Net.WebClient).DownloadFile(\"#{wins_ruby_installer_url}\", \"#{wins_ruby_installer_exe}\")"
  wins_download_ruby = "#{wins_enable_tls12} ; #{wins_download_file}"
  wins_install_ruby  = "#{wins_ruby_installer_exe} /dir=\"c:/wins_ruby\" /tasks=modpath,noassocfiles,noridkinstall" # /silent or /verysilent

  agents.each do |agent|
    # On a Linux host with only the 'agent' role, the puppet command fails when another Ruby is installed earlier in the PATH:
    #
    # [root@agent ~]# env PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/opt/puppetlabs/bin" puppet apply  -e ' notify { "Hello": }'
    # Activating bundler (2.0.2) failed:
    # Could not find 'bundler' (= 2.0.2) among 5 total gem(s)
    # To install the version of bundler this project requires, run `gem install bundler -v '2.0.2'`
    #
    # Magically, the puppet command succeeds on a Linux host with both the 'master' and 'agent' roles.
    next unless agent['roles'].include?('master') || agent['template'].include?('windows')

    beaker_path = agent.get_env_var('PATH')

    step "Setup: Install Ruby, and reset PATH on Linux" do
      if agent['platform'].include?('windows')
        on(agent, powershell(wins_download_ruby), :catch_failures => true)
        on(agent, powershell(wins_install_ruby), :catch_failures => true)
      else
        agent.add_env_var('PATH', puppet_agent_sh_path)
        package_present(agent, 'ruby')
      end
    end

    step "Install a gem package" do
      package_manifest = resource_manifest('package', package, { ensure: 'present', provider: 'gem' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, 'gem list').stdout
        assert_match(/#{package} \(/, list)
      end
      on(agent, "gem uninstall #{package}")
    end

    step "Uninstall a gem package" do
      on(agent, "gem install #{package}")
      package_manifest = resource_manifest('package', package, { ensure: 'absent', provider: 'gem' } )
      apply_manifest_on(agent, package_manifest, :catch_failures => true) do
        list = on(agent, 'gem list').stdout
        assert_no_match(/#{package} \(/, list)
      end
    end

    # Puppet's Ruby is a convenient Ruby that should not be first in the PATH.
    # Another could be: https://www.softwarecollections.org/en/scls/rhscl/rh-ruby23/

    puppet_gem_command = "#{agent['privatebindir']}#{File::SEPARATOR}gem"

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

    step "Teardown: Remove Ruby, and reset PATH on Linux" do
      if agent['platform'].include?('windows')
        package_absent(agent, "Ruby #{wins_ruby_version}")
      else
        package_absent(agent, 'ruby')
        agent.add_env_var('PATH', beaker_path)
      end
    end
  end
end
