test_name "puppet apply should show a notice"
apply_manifest_on(agents, "notice 'Hello World'") do
    fail_test "the notice didn't show" unless
        stdout =~ /notice: .*: Hello World/
end
