test_name "tests that puppet correctly runs an exec."
# original author: Dan Bode  --daniel 2010-12-23

$touch = "/tmp/test-exec-#{Time.new.to_i}"

def before
    step "file to be touched should not exist."
    on agents, "rm -f #{$touch}"
end

def after
    step "checking the output worked"
    on agents, "test -f #{$touch}"

    step "clean up the system"
    on agents, "rm -f #{$touch}"
end

before
apply_manifest_on(agents, "exec {'test': command=>'/bin/touch #{$touch}'}") do
    fail_test "didn't seem to run the command" unless
        stdout.include? 'executed successfully'
end
after

before
on(agents, puppet_resource('-d', 'exec', 'test', "command='/bin/touch #{$touch}'")) do
    fail_test "didn't seem to run the command" unless
        stdout.include? 'executed successfully'
end
after
