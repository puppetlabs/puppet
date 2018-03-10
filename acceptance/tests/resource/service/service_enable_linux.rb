test_name 'SysV and Systemd Service Provider Validation'

tag 'audit:medium',
    'audit:refactor',  # Investigate merging with init_on_systemd.rb
                       # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

confine :to, :platform => /el-|centos|fedora|debian|sles|ubuntu-v/
# osx covered by launchd_provider.rb
# ubuntu-[a-u] upstart covered by ticket_14297_handle_upstart.rb

package_name = {'el'     => 'httpd',
                'centos' => 'httpd',
                'fedora' => 'httpd',
                'debian' => 'apache2',
                'sles'   => 'apache2',
                'ubuntu' => 'cron', # See https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1447807
}

agents.each do |agent|
  platform = agent.platform.variant
  osname = on(agent, facter('os.name')).stdout.chomp
  majrelease = on(agent, facter('operatingsystemmajrelease')).stdout.chomp.to_i

  init_script_systemd = "/usr/lib/systemd/system/#{package_name[platform]}.service"
  symlink_systemd     = "/etc/systemd/system/multi-user.target.wants/#{package_name[platform]}.service"

  start_runlevels     = ["2", "3", "4", "5"]
  kill_runlevels      = ["0", "1", "6"]
  if platform == 'sles'
    start_runlevels   = ["3", "5"]
    kill_runlevels    = ["3", "5"]
  elsif platform == 'ubuntu'
    start_runlevels   = ["2", "3", "4", "5"]
    kill_runlevels    = ["2", "3", "4", "5"]
  end

  manifest_uninstall_package = %Q{
    package { '#{package_name[platform]}':
      ensure => absent,
    }
  }
  manifest_install_package = %Q{
    package { '#{package_name[platform]}':
      ensure => present,
    }
  }
  manifest_service_enabled = %Q{
    service { '#{package_name[platform]}':
      enable => true,
    }
  }
  manifest_service_disabled = %Q{
    service { '#{package_name[platform]}':
      enable => false,
    }
  }

  teardown do
    apply_manifest_on(agent, manifest_uninstall_package)
  end

  step "installing #{package_name[platform]}"
  apply_manifest_on(agent, manifest_install_package, :catch_failures => true)

  step "ensure enabling service creates the start & kill symlinks"
  # amazon linux is based on el: v1 uses a 4-digit year for its majrelease
  # and is based on el-6 (sysV). v2 returns a single-digit version for its
  # majrelease and is based on el-7 (systemd).
  is_sysV = ((platform == 'centos' || platform == 'el') && osname != 'Amazon' && majrelease < 7) ||
             (osname == 'Amazon' && majrelease > 2010) ||
             platform == 'debian' || platform == 'ubuntu' ||
             (platform == 'sles' && majrelease < 12)
  apply_manifest_on(agent, manifest_service_disabled, :catch_failures => true)
  apply_manifest_on(agent, manifest_service_enabled, :catch_failures => true) do
    if is_sysV
      # debian platforms using sysV put rc runlevels directly in /etc/
      on agent, "ln -s /etc/ /etc/rc.d", :accept_all_exit_codes => true
      rc_symlinks = on(agent, "find /etc/ -name *#{package_name[platform]}", :accept_all_exit_codes => true).stdout
      start_runlevels.each do |runlevel|
        assert_match(/rc#{runlevel}\.d\/S\d\d#{package_name[platform]}/, rc_symlinks, "did not find start symlink for #{package_name[platform]} in runlevel #{runlevel}")
        assert_match(/\/etc(\/rc\.d)?\/init\.d\/#{package_name[platform]}/, rc_symlinks, "did not find #{package_name[platform]} init script")
      end

      # Temporary measure until the Ubuntu SysV bugs are fixed. The cron service doesn't keep kill symlinks around while
      # the service is enabled, unlike Apache2.
      unless platform == 'ubuntu'
        kill_runlevels.each do |runlevel|
          assert_match(/rc#{runlevel}\.d\/K\d\d#{package_name[platform]}/, rc_symlinks, "did not find kill symlink for #{package_name[platform]} in runlevel #{runlevel}")
        end
      end
    else
      rc_symlinks = on(agent, "ls #{symlink_systemd} #{init_script_systemd}", :accept_all_exit_codes => true).stdout
      assert_match("#{symlink_systemd}",     rc_symlinks, "did not find #{symlink_systemd}")
      assert_match("#{init_script_systemd}", rc_symlinks, "did not find #{init_script_systemd}")
    end
  end

  step "ensure disabling service removes start symlinks"
  apply_manifest_on(agent, manifest_service_disabled, :catch_failures => true) do
    if is_sysV
      rc_symlinks = on(agent, "find /etc/ -name *#{package_name[platform]}", :accept_all_exit_codes => true).stdout
      # sles removes rc.d symlinks
      if platform != 'sles'
        (start_runlevels + kill_runlevels).each do |runlevel|
          assert_match(/rc#{runlevel}\.d\/K\d\d#{package_name[platform]}/, rc_symlinks, "did not find kill symlink for #{package_name[platform]} in runlevel #{runlevel}")
        end
      end
    else
      rc_symlinks = on(agent, "ls #{symlink_systemd}", :accept_all_exit_codes => true).stdout
      refute_match("#{symlink_systemd}",     rc_symlinks, "should not have found #{symlink_systemd}")
    end
  end
end
