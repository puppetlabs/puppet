test_name 'SysV and Systemd Service Provider Validation'

confine :except, :platform => 'windows'
confine :except, :platform => /osx/  # covered by launchd_provider.rb
confine :except, :platform => 'solaris'
confine :except, :platform => /ubuntu-[a-u]/ # upstart covered by ticket_14297_handle_upstart.rb

package_name = {'el'     => 'httpd',
                'centos' => 'httpd',
                'fedora' => 'httpd',
                'debian' => 'apache2',
                'sles'   => 'apache2',
                'ubuntu' => 'apache2',
}

start_runlevels     = ["2", "3", "4", "5"]
kill_runlevels      = ["0", "1", "6"]

agents.each do |agent|
  platform = agent.platform.variant
  majrelease = on(agent, facter('operatingsystemmajrelease')).stdout.chomp.to_i

  if ((platform == 'debian' && majrelease == 8) || (platform == 'ubuntu' && majrelease == 15))
    skip_test 'legit failures on debian8 and ubuntu15; see: PUP-5149'
  end

  init_script_systemd = "/usr/lib/systemd/system/#{package_name[platform]}.service"
  symlink_systemd     = "/etc/systemd/system/multi-user.target.wants/#{package_name[platform]}.service"

  init_script         = "/etc/init.d/#{package_name[platform]}"
  if platform == 'debian' && majrelease == 6
    start_symlink     = "S20apache2"
    kill_symlink      = "K01apache2"
  elsif platform == 'debian' && majrelease == 7
    start_symlink     = "S17apache2"
    kill_symlink      = "K01apache2"
  elsif platform == 'debian' && majrelease == 8
    start_symlink     = "S02apache2"
    kill_symlink      = "K01apache2"
  else
    start_symlink     = "S85httpd"
    kill_symlink      = "K15httpd"
  end

  manifest_uninstall_httpd = %Q{
    package { '#{package_name[platform]}':
      ensure => absent,
    }
  }
  manifest_install_httpd = %Q{
    package { '#{package_name[platform]}':
      ensure => present,
    }
  }
  manifest_httpd_enabled = %Q{
    service { '#{package_name[platform]}':
      enable => true,
    }
  }
  manifest_httpd_disabled = %Q{
    service { '#{package_name[platform]}':
      enable => false,
    }
  }

  teardown do
    apply_manifest_on(agent, manifest_uninstall_httpd)
  end

  if platform == 'fedora' && majrelease > 21
    # This is a reminder so we update the provider's defaultfor when new
    # versions of Fedora are released (then update this test)
    fail_test "Provider needs manual update to support Fedora #{majrelease}"
  end

  step "installing httpd/apache"
  apply_manifest_on(agent, manifest_install_httpd, :catch_failures => true)
  # chkconfig --del will remove all rc.d symlinks for this service
  on agent, "chkconfig --del httpd", :accept_all_exit_codes => true

  step "ensure enabling service creates the start & kill symlinks"
  is_sysV = ((platform == 'centos' || platform == 'el') && majrelease < 7) || platform == 'debian'
  apply_manifest_on(agent, manifest_httpd_enabled, :catch_failures => true) do
    if is_sysV
      # debian platforms using sysV put rc runlevels directly in /etc/
      on agent, "ln -s /etc/ /etc/rc.d", :accept_all_exit_codes => true
      start_runlevels.each do |runlevel|
        on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{start_symlink} && test -f #{init_script}"
      end
      kill_runlevels.each do |runlevel|
        on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{kill_symlink} && test -f #{init_script}"
      end
    else
      on agent, "test -L #{symlink_systemd} && test -f #{init_script_systemd}"
    end
  end

  step "ensure disabling service removes start symlinks"
  apply_manifest_on(agent, manifest_httpd_disabled, :catch_failures => true) do
    if is_sysV
      (start_runlevels + kill_runlevels).each do |runlevel|
        on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{kill_symlink} && test -f #{init_script}"
      end
    else
      on agent, "test ! -e #{symlink_systemd}"
    end
  end
end
