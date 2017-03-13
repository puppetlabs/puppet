test_name "should create an entry for an SSH host key"

confine :except, :platform => ['windows']

host_keys = '/etc/ssh/ssh_known_hosts'
name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) restore the #{host_keys} file
    on(agent, "test -a /tmp/host_keys && mv /tmp/host_keys #{host_keys}", :acceptable_exit_codes => [0,1])
  end

  #------- SETUP -------#
  step "(setup) backup #{host_keys} file if it exists"
  on(agent, "test -a #{host_keys} && cp #{host_keys} /tmp/host_keys", :acceptable_exit_codes => [0,1])

  #------- TESTS -------#
  step "create an SSH host key entry with puppet (present)"
  args = ['ensure=present',
          "type='rsa'",
          "key='mykey'",
         ]
  on(agent, puppet_resource('sshkey', "#{name}", args))

  step "verify entry in #{host_keys}"
  on(agent, "test -a #{host_keys} && cat #{host_keys}") do |res|
    fail_test "didn't find the sshkey for #{name}" unless stdout.include? "#{name}"
  end

end
