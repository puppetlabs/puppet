test_name "should query hosts out of a hosts file"

file = "/tmp/hosts-#{Time.new.to_i}"

step "set up the system for the test"
on agents, "printf '127.0.0.1 localhost.local localhost\n' > #{file}"

step "fetch the list of hosts from puppet"
on(agents, puppet_resource('host', 'localhost', "target=#{file}")) do
    found = stdout.scan('present').length
    fail_test "found #{found} hosts, not 1" if found != 1
end

step "clean up the system"
on agents, "rm -vf #{file}"
