test_name "should be able to modify a host address"

file = "/tmp/hosts-#{Time.new.to_i}"

step "set up files for the test"
on agents, "printf '127.0.0.9 test alias\n' > #{file}"

step "modify the resource"
on(agents, puppet_resource('host', 'test', "target=#{file}",
              'ensure=present', 'ip=127.0.0.10', 'host_aliases=alias'))

step "verify that the content was updated"
on(agents, "cat #{file}; rm -f #{file}") do
    fail_test "the address was not updated" unless
        stdout =~ /^127\.0\.0\.10[[:space:]]+test[[:space:]]+alias[[:space:]]*$/
end

step "clean up after the test"
on agents, "rm -vf #{file}"
