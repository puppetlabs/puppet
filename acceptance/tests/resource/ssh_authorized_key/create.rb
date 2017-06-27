test_name "should create an entry for an SSH authorized key"

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
  on(agent, "chown $LOGNAME #{auth_keys}")

  #------- TESTS -------#
  step "create an authorized key entry with puppet (present)"
  args = ['ensure=present',
          "user=$LOGNAME",
          "type='rsa'",
          "key='mykey'",
         ]
  on(agent, puppet_resource('ssh_authorized_key', "#{name}", args))

  step "verify entry in #{auth_keys}"
  on(agent, "cat #{auth_keys}")  do |res|
    fail_test "didn't find the ssh_authorized_key for #{name}" unless stdout.include? "#{name}"
  end

end
