test_name 'puppet apply --trace should provide a stack trace'

tag 'audit:low',
    'audit:unit',  # This should be covered at the unit layer.
    'audit:delete'

agents.each do |agent|
  on(agent, puppet('apply --trace -e "blue < 2"'), :acceptable_exit_codes => 1) do
    assert_match(/\.rb:\d+:in `\w+'/m, stderr, "Did not print expected stack trace on stderr")
  end
end
