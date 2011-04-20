test_name "should create directory"

target = "/tmp/test-#{Time.new.to_i}"

step "clean up the system before we begin"
on agents, "rm -vrf #{target}"

step "verify we can create a directory"
on(agents, puppet_resource("file", target, 'ensure=directory'))

step "verify the directory was created"
on agents, "test -d #{target}"

step "clean up after the test run"
on agents, "rm -vrf #{target}"
