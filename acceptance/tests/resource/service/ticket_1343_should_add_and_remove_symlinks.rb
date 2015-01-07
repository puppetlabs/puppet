test_name 'RedHat Service Symlink Validation'

confine :to, :platform => 'el-5' 

manifest_httpd_setup = %Q{
  package { 'httpd':
    ensure => present,
  }
}

manifest_httpd_enabled = %Q{
  package { 'httpd':
    ensure => present,
  }
  service { 'httpd':
    enable => true,
  }
}

manifest_httpd_disabled = %Q{
  package { 'httpd':
    ensure => present,
  }
  service { 'httpd':
    enable => false,
  }
}

init_script = "/etc/init.d/httpd"
start_symlink = "S85httpd"
kill_symlink = "K15httpd"

start_runlevels = ["2", "3", "4", "5"]
kill_runlevels = ["0", "1", "6"]

agents.each do |agent|
  step "setting up test preconditions"
  apply_manifest_on(agent, manifest_httpd_setup, :catch_failures => true) do
    # chkconfig --del will remove all rc.d symlinks for this service
    on agent, "chkconfig --del httpd"
  end

  step "ensure enabling httpd creates the S-symlinks"
  apply_manifest_on(agent, manifest_httpd_enabled, :catch_failures => true) do
    start_runlevels.each do |runlevel|
      on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{start_symlink} && test -f #{init_script}"
    end
  end

  step "ensure enabling httpd creates the K-symlinks"
  apply_manifest_on(agent, manifest_httpd_enabled, :catch_failures => true) do
    kill_runlevels.each do |runlevel|
      on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{kill_symlink} && test -f #{init_script}"
    end
  end
end
