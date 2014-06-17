test_name "should update an entry for an SSH host key"

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
  step "update an SSH host key entry with puppet (present)"
  args = ['ensure=present',
          "type='rsa'",
          "key='mynewshinykey'",
         ]
  on(agent, puppet_resource('sshkey', "#{name}", args))

  step "verify entry updated in #{host_keys}"
  on(agent, "cat #{host_keys}")  do |res|
    fail_test "didn't find the updated key for #{name}" unless stdout.include? "#{name} ssh-rsa mynewshinykey"
  end

end
