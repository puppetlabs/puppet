test_name "should be able to remove a host record"

file = "/tmp/hosts-#{Time.new.to_i}"
line = "127.0.0.7 test1"

step "set up files for the test"
on agents, "printf '#{line}\n' > #{file}"

step "delete the resource from the file"
on(agents, puppet_resource('host', 'test1', "target=#{file}",
              'ensure=absent', 'ip=127.0.0.7'))

step "verify that the content was removed"
on(agents, "cat #{file}; rm -f #{file}") do
    fail_test "the content was still present" if stdout.include? line
end

step "clean up after the test"
on agents, "rm -vf #{file}"
