test_name 'RedHat Service vs. Systemd Provider Validation'

# A simple acceptance test to ensure basic usage of the service
# provider works for a mix of sysV and systemd RedHat Linux platforms
confine :to, :platform => /el|centos|fedora/

manifest_install_httpd = %Q{
  package { 'httpd':
    ensure => present,
  }
}

manifest_httpd_enabled = %Q{
  service { 'httpd':
    enable => true,
  }
}

manifest_httpd_disabled = %Q{
  service { 'httpd':
    enable => false,
  }
}

agents.each do |agent|
  distro = on(agent, facter('operatingsystem')).stdout.chomp
  if distro == 'fedora'
    majrelease = on(agent, facter('operatingsystemmajrelease')).stdout.chomp.to_i
    if majrelease < 17
      skip_test "Test not applicable to Fedora #{majrelease}"
    elsif majrelease > 21
      # This is a reminder so we update the provider's defaultfor when new
      # versions of Fedora are released (then update this test)
      fail_test "Provider needs manual update to support Fedora #{majrelease}"
    end
  end

  step "installing httpd"
  apply_manifest_on(agent, manifest_install_httpd, :catch_failures => true)

  step "enabling httpd"
  apply_manifest_on(agent, manifest_httpd_enabled, :catch_failures => true)

  step "disabling httpd"
  apply_manifest_on(agent, manifest_httpd_disabled, :catch_failures => true)
end
