require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

test_name 'Systemd masked services are unmasked before attempting to start'

# This test in intended to ensure that a service which was previously marked
# as masked and then set to enabled will first be unmasked.
confine :to, {}, agents.select { |agent| supports_systemd?(agent) }
package_name = {'el'     => 'httpd',
                'centos' => 'httpd',
                'fedora' => 'httpd',
                'debian' => 'apache2',
                'sles'   => 'apache2',
                'ubuntu' => 'apache2',
}

agents.each do |agent|
  platform = agent.platform.variant
  majrelease = on(agent, facter('os.release.major')).stdout.chomp

  if ((platform == 'debian' && majrelease == '8') || (platform == 'ubuntu' && majrelease == '15.04'))
    skip_test 'legit failures on debian8 and ubuntu15; see: PUP-5149'
  end

  init_script_systemd    = "/usr/lib/systemd/system/#{package_name[platform]}.service"
  symlink_systemd        = "/etc/systemd/system/multi-user.target.wants/#{package_name[platform]}.service"
  masked_symlink_systemd = "/etc/systemd/system/#{package_name[platform]}.service"

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
  manifest_httpd_masked = %Q{
    service { '#{package_name[platform]}':
      provider => systemd,
      enable => mask,
    }
  }
  manifest_httpd_enabled = %Q{
    service { '#{package_name[platform]}':
      provider => systemd,
      enable => true,
      ensure => running,
    }
  }

  teardown do
    if platform == 'sles'
      on agent, 'zypper remove -y apache2 apache2-prefork apache2-worker libapr1 libapr-util1'
    else
      apply_manifest_on(agent, manifest_uninstall_httpd)
    end
  end

  step "Installing httpd"
  apply_manifest_on(agent, manifest_install_httpd, :catch_failures => true)

  step "Masking the httpd service"
  apply_manifest_on(agent, manifest_httpd_masked, :catch_failures => true)
  on(agent, puppet_resource('service', package_name[platform])) do
    assert_match(/ensure => 'stopped'/, stdout, "Expected httpd service to be stopped")
    assert_match(/enable => 'false'/, stdout, "Expected httpd service to be masked")
    on(agent, "readlink #{masked_symlink_systemd}") do
      assert_equal('/dev/null', stdout.chomp, "Expected service symlink to point to /dev/null")
    end
  end

  step "Enabling the httpd service"
  apply_manifest_on(agent, manifest_httpd_enabled, :catch_failures => true)
  on(agent, puppet_resource('service', package_name[platform])) do
    assert_match(/ensure => 'running'/, stdout, "Expected httpd service to be running")
    assert_match(/enable => 'true'/, stdout, "Expected httpd service to be enabled")
    on(agent, "readlink #{symlink_systemd}") do
      assert_equal(init_script_systemd, stdout.chomp, "Expected service symlink to point to systemd init script")
    end
  end
end
