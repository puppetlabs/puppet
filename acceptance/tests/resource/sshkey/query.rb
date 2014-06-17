test_name "should be able to find an existing SSH host key"

confine :except, :platform => ['windows']

host_keys = '/etc/ssh/ssh_known_hosts'
name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) restore the #{host_keys} file
    on(agent, "mv /tmp/host_keys #{host_keys}", :acceptable_exit_codes => [0,1])
  end

  #------- SETUP -------#
  step "(setup) backup #{host_keys} file"
  on(agent, "cp #{host_keys} /tmp/host_keys", :acceptable_exit_codes => [0,1])

  step "(setup) create a host key in the #{host_keys} file"
  on(agent, "echo '#{name} ssh-rsa mykey' >> #{host_keys}")

  #------- TESTS -------#
  step "verify SSH host key query with puppet"
  on(agent, puppet_resource('sshkey', "#{name}")) do |res|
    fail_test "didn't find the SSH host key for #{name}" unless stdout.include? "#{name}"
  end

end
