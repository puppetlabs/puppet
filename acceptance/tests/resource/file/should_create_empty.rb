test_name "should create empty file for 'present'"

target = "/tmp/test-#{Time.new.to_i}"

step "clean up the system before we begin"
on agents, "rm -vrf #{target}"

step "verify we can create an empty file"
on(agents, puppet_resource("file", target, 'ensure=present'))

step "verify the target was created"
on agents, "test -f #{target} && ! test -s #{target}"

step "clean up after the test run"
on agents, "rm -vrf #{target}"
