require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

test_name 'Systemd masked services are unmasked before attempting to start'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

skip_test "requires AIO install to require 'puppet'" if @options[:type] != 'aio'

# This test in intended to ensure that a service which was previously marked
# as masked and then set to enabled will first be unmasked.
confine :to, {}, agents.select { |agent| supports_systemd?(agent) }
package_name = {'el'     => 'httpd',
                'centos' => 'httpd',
                'fedora' => 'httpd',
                'sles'   => 'apache2',
                'debian' => 'cron', # apache2 does not create systemd service symlinks in Debian
                'ubuntu' => 'cron', # See https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1447807
}

agents.each do |agent|
  platform = agent.platform.variant

  if agent['platform'] =~ /(debian|ubuntu)/
    init_script_systemd = "/lib/systemd/system/#{package_name[platform]}.service"
  else
    init_script_systemd = "/usr/lib/systemd/system/#{package_name[platform]}.service"
  end

  symlink_systemd = "/etc/systemd/system/multi-user.target.wants/#{package_name[platform]}.service"
  masked_symlink_systemd = "/etc/systemd/system/#{package_name[platform]}.service"

  manifest_uninstall_package = %Q{
    package { '#{package_name[platform]}':
      ensure => absent,
    }
  }
  manifest_install_package = %Q{
    package { '#{package_name[platform]}':
      ensure => present,
    }
    if ($::operatingsystem == 'Fedora') and ($::operatingsystemmajrelease == '23') {
      package{'libnghttp2':
        ensure => latest,
        install_options => '--best',
        before => Package['httpd'],
      }
    }
  }
  manifest_service_masked = %Q{
    service { '#{package_name[platform]}':
      enable => mask,
      ensure => stopped,
    }
  }
  manifest_service_enabled = %Q{
    service { '#{package_name[platform]}':
      enable => true,
      ensure => running,
    }
  }

  teardown do
    if platform == 'sles'
      on agent, 'zypper remove -y apache2 apache2-prefork libapr1 libapr-util1'
    else
      apply_manifest_on(agent, manifest_uninstall_package)
    end
  end

  step "Installing #{package_name[platform]}"
  apply_manifest_on(agent, manifest_install_package, :catch_failures => true)

  step "Masking the #{package_name[platform]} service"
  apply_manifest_on(agent, manifest_service_masked, :catch_failures => true)
  on(agent, puppet_resource('service', package_name[platform])) do
    assert_match(/ensure => 'stopped'/, stdout, "Expected #{package_name[platform]} service to be stopped")
    assert_match(/enable => 'false'/, stdout, "Expected #{package_name[platform]} service to be masked")
    on(agent, "readlink #{masked_symlink_systemd}") do
      assert_equal('/dev/null', stdout.chomp, "Expected service symlink to point to /dev/null")
    end
  end

  step "Enabling the #{package_name[platform]} service"
  apply_manifest_on(agent, manifest_service_enabled, :catch_failures => true)
  on(agent, puppet_resource('service', package_name[platform])) do
    assert_match(/ensure => 'running'/, stdout, "Expected #{package_name[platform]} service to be running")
    assert_match(/enable => 'true'/, stdout, "Expected #{package_name[platform]} service to be enabled")
    on(agent, "readlink #{symlink_systemd}") do
      assert_equal(init_script_systemd, stdout.chomp, "Expected service symlink to point to systemd init script")
    end
  end
end
