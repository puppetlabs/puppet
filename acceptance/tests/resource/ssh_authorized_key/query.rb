test_name "should be able to find an existing SSH authorized key"

skip_test("This test is blocked by PUP-1605")

confine :except, :platform => ['windows']

auth_keys = '~/.ssh/authorized_keys'
name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) restore the #{auth_keys} file
    on(agent, "mv /tmp/auth_keys #{auth_keys}", :acceptable_exit_codes => [0,1])
  end

  #------- SETUP -------#
  step "(setup) backup #{auth_keys} file"
  on(agent, "cp #{auth_keys} /tmp/auth_keys", :acceptable_exit_codes => [0,1])

  step "(setup) create an authorized key in the #{auth_keys} file"
  on(agent, "echo 'ssh-rsa mykey #{name}' >> #{auth_keys}")

  #------- TESTS -------#
  step "verify SSH authorized key query with puppet"
  on(agent, puppet_resource('ssh_authorized_key', "/#{name}")) do |res|
    fail_test "found the ssh_authorized_key for #{name}" unless stdout.include? "#{name}"
  end

end
