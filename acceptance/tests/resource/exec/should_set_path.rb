test_name "the path statement should work to locate commands"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  file = agent.tmpfile('touched-should-set-path')

  step "clean up the system for the test"
  on agent, "rm -f #{file}"

  step "invoke the exec resource with a path set"
  on(agent, puppet_resource('exec', 'test',
                   "command='#{agent.touch(file, false)}'", "path='#{agent.path}'"))

  step "verify that the files were created"
  on agent, "test -f #{file}"

  step "clean up the system after testing"
  on agent, "rm -f #{file}"
end
