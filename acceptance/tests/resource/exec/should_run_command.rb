test_name "tests that puppet correctly runs an exec."
# original author: Dan Bode  --daniel 2010-12-23

tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

def before(agent)
  step "file to be touched should not exist."
  touched = agent.tmpfile('test-exec')
end

def after(agent, touched)
  step "checking the output worked"
  on agent, "test -f #{touched}"

  step "clean up the system"
  on agent, "rm -f #{touched}"
end

agents.each do |agent|
  touched = before(agent)
  apply_manifest_on(agent, "exec {'test': command=>'#{agent.touch(touched)}'}") do
    fail_test "didn't seem to run the command" unless
      stdout.include? 'executed successfully' unless agent['locale'] == 'ja'
  end
  after(agent, touched)

  touched = before(agent)
  on(agent, puppet_resource('-d', 'exec', 'test', "command='#{agent.touch(touched)}'}")) do
    fail_test "didn't seem to run the command" unless
      stdout.include? 'executed successfully' unless agent['locale'] == 'ja'
  end
  after(agent, touched)
end


