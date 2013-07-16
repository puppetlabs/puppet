test_name "should create directory"

agents.each do |agent|
  target = agent.tmpfile("create-dir")

  step "clean up the system before we begin"
  on(agent, "rm -rf #{target}")

  step "verify we can create a directory"
  on(agent, puppet_resource("file", target, 'ensure=directory'))

  step "verify the directory was created"
  on(agent, "test -d #{target}")

  step "clean up after the test run"
  on(agent, "rm -rf #{target}")
end
