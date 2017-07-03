test_name "should create empty file for 'present'"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  target = agent.tmpfile("empty")

  step "clean up the system before we begin"
  on(agent, "rm -rf #{target}")

  step "verify we can create an empty file"
  on(agent, puppet_resource("file", target, 'ensure=present'))

  step "verify the target was created"
  on(agent, "test -f #{target} && test ! -s #{target}")

  step "clean up after the test run"
  on(agent, "rm -rf #{target}")
end
