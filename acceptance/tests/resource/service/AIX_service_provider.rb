test_name 'AIX Service Provider Testing'

confine :to, :platform =>  'aix'

sloth_daemon_script = <<SCRIPT
#!/usr/bin/env sh
while true; do sleep 1; done
SCRIPT

agents.each do |agent|

	## Setup
  step "Create the sloth_daemon service on #{agent}"
	sloth_daemon_path = agent.tmpfile("sloth_daemon.sh")
	create_remote_file(agent, sloth_daemon_path, sloth_daemon_script)
	on agent, "chmod +x #{sloth_daemon_path}"
	on agent, "mkssys -s sloth_daemon -p #{sloth_daemon_path} -u 0 -S -n 15 -f 9"

	## Start the service


	## Stop the service


	## Enable the service


	## Disable the service


	## Cleanup
	step "Remove the sloth_daemon service on #{agent}"
	on agent, "rmssys -s sloth_daemon"
	on agent, "rm #{sloth_daemon_path}"

end