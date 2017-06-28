test_name "should delete an entry for an SSH authorized key"

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
  on(agent, "echo '' >> #{auth_keys} && echo 'ssh-rsa mykey #{name}' >> #{auth_keys}")
  on(agent, "chown $LOGNAME #{auth_keys}")

  #------- TESTS -------#
  step "delete an authorized key entry with puppet (absent)"
  args = ['ensure=absent',
          "user=$LOGNAME",
          "type='rsa'",
          "key='mykey'",
         ]
  on(agent, puppet_resource('ssh_authorized_key', "#{name}", args))

  step "verify entry deleted from #{auth_keys}"
  on(agent, "cat #{auth_keys}")  do |res|
    fail_test "found the ssh_authorized_key for #{name}" if stdout.include? "#{name}"
  end

end
