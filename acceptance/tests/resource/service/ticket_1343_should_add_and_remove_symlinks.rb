test_name 'RedHat Service Symlink Validation'

confine :to, :platform => /el\-5|el\-6|el\-7|centos\-5|centos\-6|centos\-7/

# netconsole is one of the only services which triggers this bug and
# exists across RHEL v5-v7 (but can still use chkconfig in v7, which
# is why we specify provider => redhat)
manifest_netconsole_enabled = %Q{
  service { 'netconsole':
    enable => true,
    provider => redhat,
  }
}

init_script = "/etc/init.d/netconsole"
start_symlink = "S50netconsole"
kill_symlink = "K50netconsole"

start_runlevels = ["2", "3", "4", "5"]
kill_runlevels = ["0", "1", "6"]

agents.each do |agent|
  step "setting up test preconditions"
  # chkconfig --del will remove all rc.d symlinks for this service
  on agent, "chkconfig --del netconsole"

  step "ensure enabling the netconsole service creates the S-symlinks"
  apply_manifest_on(agent, manifest_netconsole_enabled, :catch_failures => true) do
    start_runlevels.each do |runlevel|
      on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{start_symlink} && test -f #{init_script}"
    end
  end

  step "ensure enabling the netconsole service creates the K-symlinks"
  apply_manifest_on(agent, manifest_netconsole_enabled, :catch_failures => true) do
    kill_runlevels.each do |runlevel|
      on agent, "test -L /etc/rc.d/rc#{runlevel}.d/#{kill_symlink} && test -f #{init_script}"
    end
  end
end
