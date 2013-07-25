test_name "Puppet Master sanity checks: PID file and SSL dir creation"

pidfile = '/var/lib/puppet/run/master.pid'

with_master_running_on(master, "--dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --verbose --noop") do
  # SSL dir created?
  step "SSL dir created?"
  on master,  "[ -d #{master['puppetpath']}/ssl ]"

  # PID file exists?
  step "PID file created?"
  on master, "[ -f #{pidfile} ]"
end
