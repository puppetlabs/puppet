test_name "should remove file"

target = "/tmp/test-#{Time.new.to_i}"

step "clean up the system before we begin"
on agents, "rm -vrf #{target} && touch #{target}"

step "verify we can remove a file"
on(agents, puppet_resource("file", target, 'ensure=absent'))

step "verify that the file is gone"
on agents, "test -e #{target}", :acceptable_exit_codes => [1]
