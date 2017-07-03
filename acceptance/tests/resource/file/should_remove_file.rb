test_name "should remove file"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  target = agent.tmpfile('delete-file')

  step "clean up the system before we begin"
  on agent, "rm -rf #{target} && touch #{target}"

  step "verify we can remove a file"
  on(agent, puppet_resource("file", target, 'ensure=absent'))

  step "verify that the file is gone"
  on agent, "test -e #{target}", :acceptable_exit_codes => [1]
end
