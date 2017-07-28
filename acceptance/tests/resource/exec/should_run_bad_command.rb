test_name "tests that puppet can run badly written scripts that fork and inherit descriptors"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

def sleepy_daemon_script(agent)
  if agent['platform'] =~ /win/
    # Windows uses a shorter sleep, because it's expected to wait until the end.
    return <<INITSCRIPT
echo hello
start /b ping.exe 127.0.0.1 -n 1
INITSCRIPT
  else
    return <<INITSCRIPT
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
  # On Windows, Puppet waits until the sleep process exits before exiting
  stop_sleep_process(agents.select {|agent| agent['platform'] =~ /win/}, true)
  # Requiring a sleep process asserts that Puppet exited before the sleep process.
  stop_sleep_process(agents.reject {|agent| agent['platform'] =~ /win/})
end

agents.each do |agent|
  ext = if agent['platform'] =~ /win/ then '.bat' else '' end
  daemon = agent.tmpfile('sleepy_daemon') + ext
  create_remote_file(agent, daemon, sleepy_daemon_script(agent))
  on(agent, "chmod +x #{daemon}")

  apply_manifest_on(agent, "exec {'#{daemon}': logoutput => true}") do
    fail_test "didn't seem to run the command" unless
      stdout.include? 'executed successfully' unless agent['locale'] == 'ja'
  end
end

