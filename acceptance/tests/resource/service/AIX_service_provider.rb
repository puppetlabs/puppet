test_name 'AIX Service Provider Testing'

confine :to, :platform =>  'aix'

require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

sloth_daemon_script = <<SCRIPT
#!/usr/bin/env sh
while true; do sleep 1; done
SCRIPT

def assert_service_enable(host, service, expected_status)
  case expected_status
  when "true"
    expected_output = service
  when "false"
    expected_output = ''
  else
    raise "This test doesn't know what to do with an expected enable status of #{expected_status}"
  end

  on host, "lsitab #{service} | cut -f 1 -d :" do
    actual_output = stdout.chomp
    assert_equal(expected_output, actual_output,
      "Service doesn't actually have enabled = #{expected_status}")
  end
end

def assert_service_status(host, service, expected_status)
  case expected_status
  when "running"
    expected_output = 'active'
  when "stopped"
    expected_output = 'inoperative'
  else
    raise "This test doesn't know what to do with an expected status of #{expected_status}"
  end

  # sometimes there's no group or PID which messes up the condense to a single
  # delimiter
  on host, "lssrc -s #{service} | tr -s ' ' ':' | tail -1 | cut -f 3- -d :" do
    actual_output = stdout.chomp
    assert_match(/#{expected_output}\Z/, actual_output,
        "Service is not actually #{expected_status}")
  end
end

agents.each do |agent|

  ## Setup
  step "Setup on #{agent}"
  sloth_daemon_path = agent.tmpfile("sloth_daemon.sh")
  create_remote_file(agent, sloth_daemon_path, sloth_daemon_script)
  on agent, "chmod +x #{sloth_daemon_path}"
  on agent, "mkssys -s sloth_daemon -p #{sloth_daemon_path} -u 0 -S -n 15 -f 9"

  teardown do
    on agent, "rmssys -s sloth_daemon"
    on agent, "rm #{sloth_daemon_path}"
  end

  ## Query
  step "Verify the service exists on #{agent}"
  on(agent, puppet_resource('service', 'sloth_daemon')) do
    assert_match(/sloth_daemon/, stdout, "Couldn't find service sloth_daemon")
  end

  ## Start the service
  step "Start the service on #{agent}"
  ensure_service_on_host agent, 'sloth_daemon', 'ensure', 'running'
  assert_service_status agent, 'sloth_daemon', 'running'

  ## Stop the service
  step "Stop the service on #{agent}"
  ensure_service_on_host agent, 'sloth_daemon', 'ensure', 'stopped'
  assert_service_status agent, 'sloth_daemon', 'stopped'

  ## Enable the service
  step "Enable the service on #{agent}"
  ensure_service_on_host agent, 'sloth_daemon', 'enable', 'true'
  assert_service_enable agent, 'sloth_daemon', 'true'

  ## Disable the service
  step "Disable the service on #{agent}"
  ensure_service_on_host agent, 'sloth_daemon', 'enable', 'false'
  assert_service_enable agent, 'sloth_daemon', 'false'
end
