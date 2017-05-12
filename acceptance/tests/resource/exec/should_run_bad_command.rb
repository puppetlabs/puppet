test_name "tests that puppet can run badly written scripts that fork and inherit descriptors"

def sleepy_daemon_script(agent)
  if agent['platform'] =~ /win/
    return <<INITSCRIPT
echo hello
start /b ping.exe 127.0.0.1 -n 60
INITSCRIPT
  else
    return <<INITSCRIPT
#!/usr/bin/bash
echo hello
/bin/sleep 60 &
INITSCRIPT
  end
end

# TODO: taken from pxp-agent, find common home
def stop_sleep_process(targets, accept_no_pid_found = false)
  targets = [targets].flatten

  targets.each do |target|
    case target['platform']
    when /osx/
      command = "ps -e -o pid,comm | grep sleep | sed 's/^[^0-9]*//g' | cut -d\\  -f1"
    when /win/
      command = "ps -efW | grep PING | sed 's/^[^0-9]*[0-9]*[^0-9]*//g' | cut -d ' ' -f1"
    else
      command = "ps -ef | grep 'bin/sleep ' | grep -v 'grep' | grep -v 'true' | sed 's/^[^0-9]*//g' | cut -d\\  -f1"
    end

    # A failed test may leave an orphaned sleep process, handle multiple matches.
    pids = nil
    on(target, command) do |output|
      pids = output.stdout.chomp.split
      if pids.empty? && !accept_no_pid_found
        raise("Did not find a pid for a sleep process on #{target}")
      end
    end

    pids.each do |pid|
      target['platform'] =~ /win/ ?
        on(target, "taskkill /F /pid #{pid}") :
        on(target, "kill -s TERM #{pid}")
    end
  end
end

teardown do
  # Requiring a sleep process asserts that Puppet exited before the sleep process.
  stop_sleep_process(agents)
end

agents.each do |agent|
  ext = if agent['platform'] =~ /win/ then '.bat' else '' end
  daemon = agent.tmpfile('sleepy_daemon') + ext
  create_remote_file(agent, daemon, sleepy_daemon_script(agent))
  on(agent, "chmod +x #{daemon}")

  apply_manifest_on(agent, "exec {'#{daemon}': logoutput => true}") do
    fail_test "didn't seem to run the command" unless
      stdout.include? 'executed successfully'
  end
end

