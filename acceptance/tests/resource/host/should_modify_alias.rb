test_name "should be able to modify a host alias"

file = "/tmp/hosts-#{Time.new.to_i}"

step "set up files for the test"
on agents, "printf '127.0.0.8 test alias\n' > #{file}"

step "modify the resource"
on(agents, puppet_resource('host', 'test', "target=#{file}",
              'ensure=present', 'ip=127.0.0.8', 'host_aliases=banzai'))

step "verify that the content was updated"
on(agents, "cat #{file}; rm -f #{file}") do
    fail_test "the alias was not updated" unless
        stdout =~ /^127\.0\.0\.8[[:space:]]+test[[:space:]]+banzai[[:space:]]*$/
end

step "clean up after the test"
on agents, "rm -vf #{file}"
