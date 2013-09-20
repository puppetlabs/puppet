test_name "should query hosts out of a hosts file"

agents.each do |agent|
  file = agent.tmpfile('host-query')

  step "set up the system for the test"
  on agent, "printf '127.0.0.1 localhost.local localhost\n' > #{file}"

  step "fetch the list of hosts from puppet"
  on(agent, puppet_resource('host', 'localhost', "target=#{file}")) do
    found = stdout.scan('present').length
    fail_test "found #{found} hosts, not 1" if found != 1
  end

  step "clean up the system"
  on agent, "rm -f #{file}"
end
