test_name "should create symlink"

message = 'hello world'
target  = "/tmp/test-#{Time.new.to_i}"
source  = "/tmp/test-#{Time.new.to_i}-source"

step "clean up the system before we begin"
on agents, "rm -vrf #{target}"
on agents, "echo '#{message}' > #{source}"

step "verify we can create a symlink"
on(agents, puppet_resource("file", target, "ensure=#{source}"))

step "verify the symlink was created"
on agents, "test -L #{target} && test -f #{target}"
on agents, "test -f #{source}"

step "verify the content is identical on both sides"
on(agents, "cat #{source}") do
    fail_test "source missing content" unless stdout.include? message
end
on(agents, "cat #{target}") do
    fail_test "target missing content" unless stdout.include? message
end

step "clean up after the test run"
on agents, "rm -vrf #{target} #{source}"
