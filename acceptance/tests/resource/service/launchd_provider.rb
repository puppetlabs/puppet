test_name 'Mac OS X launchd Provider Testing'

confine :to, {:platform => /osx/}, agents

sloth_daemon_script = <<SCRIPT
#!/usr/bin/env sh
while true; do sleep 1; done
SCRIPT

svc = 'com.puppetlabs.sloth'
launchd_script_path = "/Library/LaunchDaemons/#{svc}.plist"

def assert_service_status_on(host, service, status, expect_running)
  ensure_status = "ensure => '#{status[:ensure]}'" if status[:ensure]
  enable_status = "enable => '#{status[:enable]}'" if status[:enable]

  on host, puppet_resource('service', service) do
    assert_match(/'#{service}'.+#{ensure_status}.+#{enable_status}/m, stdout, "Service status does not match expectation #{status}")
  end

  on host, 'launchctl list' do
    if expect_running
      assert_match(/#{service}/, stdout, 'Service was not found in launchctl list')
    else
      assert_no_match(/#{service}/, stdout, 'Service was not expected in launchctl list')
    end
  end
end

def ensure_service_on(host, service, status, expect_running)
  ensure_status = "ensure => '#{status[:ensure]}'," if status[:ensure]
  enable_status = "enable => '#{status[:enable]}'," if status[:enable]

  apply_manifest_on host, "service { '#{service}': provider => launchd, #{ensure_status} #{enable_status} }" do
    assert_match(/Service\[#{service}\]\/ensure: ensure changed '\w+' to '#{status[:ensure]}'/, stdout,
                 'Service status change failed') if status[:ensure]
    assert_match(/Service\[#{service}\]\/enable: enable changed '\w+' to '#{status[:enable]}'/, stdout,
                 'Service enable change failed') if status[:enable]
  end
  assert_service_status_on host, service, status, expect_running

  # Ensure idempotency
  apply_manifest_on host, "service { '#{service}': provider => launchd, #{ensure_status} #{enable_status} }" do
    assert_no_match(/Service\[#{service}\]\/ensure/, stdout, 'Service status not idempotent') if status[:ensure]
    assert_no_match(/Service\[#{service}\]\/enable/, stdout, 'Service enable not idempotent') if status[:enable]
  end
  assert_service_status_on host, service, status, expect_running
end

agents.each do |agent|
  step "Setup on #{agent}"
  sloth_daemon_path = agent.tmpfile("sloth_daemon.sh")
  create_remote_file(agent, sloth_daemon_path, sloth_daemon_script)

  launchd_script = <<SCRIPT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>#{svc}</string>
        <key>Program</key>
        <string>#{sloth_daemon_path}</string>
        <key>RunAtLoad</key>
        <true/>
</dict>
</plist>
SCRIPT
  create_remote_file(agent, launchd_script_path, launchd_script)

  teardown do
    on agent, "rm #{sloth_daemon_path} #{launchd_script_path}"
  end

  step "Verify the service exists on #{agent}"
  assert_service_status_on(agent, svc, {:ensure => 'stopped', :enable => 'true'}, false)

  step "Start the service on #{agent}"
  ensure_service_on(agent, svc, {:ensure => 'running'}, true)

  step "Disable the service on #{agent}"
  ensure_service_on(agent, svc, {:enable => 'false'}, true)

  step "Stop the service on #{agent}"
  ensure_service_on(agent, svc, {:ensure => 'stopped'}, false)

  step "Enable the service on #{agent}"
  ensure_service_on(agent, svc, {:enable => 'true'}, false)
end

