test_name "should be able to find an existing SSH authorized key"

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

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
  on(agent, "echo '' >> #{auth_keys} && echo 'ssh-rsa mykey #{name}' >> #{auth_keys}")

  #------- TESTS -------#
  step "verify SSH authorized key query with puppet"
  on(agent, puppet_resource('ssh_authorized_key', "/#{name}")) do |res|
    fail_test "Didn't find the ssh_authorized_key for #{name}" unless stdout.include? "#{name}"
  end

end
