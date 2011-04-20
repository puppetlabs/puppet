test_name "host should create aliases"

target  = "/tmp/host-#{Time.new.to_i}"

step "clean up the system for testing"
on agents, "rm -vf #{target}"

step "create the record"
on(agents, puppet_resource('host', 'test', "ensure=present",
              "ip=127.0.0.7", "target=#{target}", "host_aliases=alias"))

step "verify that the aliases were added"
on(agents, "cat #{target} ; rm -f #{target}") do
    fail_test "alias was missing" unless
        stdout =~ /^127\.0\.0\.7[[:space:]]+test[[:space:]]alias/
end
