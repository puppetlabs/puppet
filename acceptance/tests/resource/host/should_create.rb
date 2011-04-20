test_name "host should create"

target = "/tmp/host-#{Time.new.to_i}"

step "clean up for the test"
on agents, "rm -vf #{target}"

step "create the host record"
on(agents, puppet_resource("host", "test", "ensure=present",
              "ip=127.0.0.1", "target=#{target}"))

step "verify that the record was created"
on(agents, "cat #{target} ; rm -f #{target}") do
    fail_test "record was not present" unless stdout =~ /^127\.0\.0\.1[[:space:]]+test/
end
