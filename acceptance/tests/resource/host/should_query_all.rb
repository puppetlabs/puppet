test_name "should query all hosts from hosts file"

content = %q{127.0.0.1 test1 test1.local
127.0.0.2 test2 test2.local
127.0.0.3 test3 test3.local
127.0.0.4 test4 test4.local
}

backup = "/tmp/hosts.backup-#{Time.new.to_i}"

step "configure the system for testing (including file backups)"
on agents, "cp /etc/hosts #{backup}"
on agents, "cat > /etc/hosts", :stdin => content

step "query all host records using puppet"
on(agents, puppet_resource('host')) do
    found = stdout.scan(/host \{ '([^']+)'/).flatten.sort
    fail_test "the list of returned hosts was wrong: #{found.join(', ')}" unless
        found == %w{test1 test2 test3 test4}

    count = stdout.scan(/ensure\s+=>\s+'present'/).length
    fail_test "found #{count} records, wanted 4" unless count == 4
end

step "clean up the system afterwards"
on agents, "mv -vf #{backup} /etc/hosts"
