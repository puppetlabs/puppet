test_name "should remove directory, but force required"

target = "/tmp/test-#{Time.new.to_i}"

step "clean up the system before we begin"
on agents, "test -e #{target} && rm -vrf #{target} ; mkdir -p #{target}"

step "verify we can't remove a directory without 'force'"
on(agents, puppet_resource("file", target, 'ensure=absent')) do
    fail_test "didn't tell us that force was required" unless
        stdout.include? "Not removing directory; use 'force' to override"
end

step "verify the directory still exists"
on agents, "test -d #{target}"

step "verify we can remove a directory with 'force'"
on(agents, puppet_resource("file", target, 'ensure=absent', 'force=true'))

step "verify that the directory is gone"
on agents, "test -d #{target}", :acceptable_exit_codes => [1]
