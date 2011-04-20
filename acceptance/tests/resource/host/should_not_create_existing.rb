test_name "should not create host if it exists"

file = "/tmp/hosts-#{Time.new.to_i}"

step "set up the system for the test"
on agents, "printf '127.0.0.2 test alias\n' > #{file}"

step "tell puppet to ensure the host exists"
on(agents, puppet_resource('host', 'test', "target=#{file}",
              'ensure=present', 'ip=127.0.0.2', 'host_aliases=alias')) do
    fail_test "darn, we created the host record" if
        stdout.include? 'notice: /Host[test1]/ensure: created'
end

step "clean up after we created things"
on agents, "rm -vf #{file}"

