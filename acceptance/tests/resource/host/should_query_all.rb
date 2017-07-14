test_name "should query all hosts from hosts file"

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

content = %q{127.0.0.1 test1 test1.local
127.0.0.2 test2 test2.local
127.0.0.3 test3 test3.local
127.0.0.4 test4 test4.local
}

agents.each do |agent|
  backup = agent.tmpfile('host-query-all')

  step "configure the system for testing (including file backups)"
  on agent, "cp /etc/hosts #{backup}"
  on agent, "cat > /etc/hosts", :stdin => content

  step "query all host records using puppet"
  on(agent, puppet_resource('host')) do
    found = stdout.scan(/host \{ '([^']+)'/).flatten.sort
    fail_test "the list of returned hosts was wrong: #{found.join(', ')}" unless
      found == %w{test1 test2 test3 test4}

    count = stdout.scan(/ensure\s+=>\s+'present'/).length
    fail_test "found #{count} records, wanted 4" unless count == 4
  end

  step "clean up the system afterwards"
  on agent, "cat #{backup} > /etc/hosts && rm -f #{backup}"
end
