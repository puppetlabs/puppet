test_name "should not run command creates"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  touch      = agent.tmpfile('touched')
  donottouch = agent.tmpfile('not-touched')

manifest = %Q{
  exec { "test#{Time.new.to_i}": command => '#{agent.touch(donottouch)}', creates => "#{touch}"}
}

  step "prepare the agents for the test"
  on agent, "touch #{touch} && rm -f #{donottouch}"

  step "test using puppet apply"
  apply_manifest_on(agent, manifest) do
    fail_test "looks like the thing executed, which it shouldn't" if
      stdout.include? 'executed successfully'
  end

  step "verify the file didn't get created"
  on agent, "test -f #{donottouch}", :acceptable_exit_codes => [1]

  step "prepare the agents for the second part of the test"
  on agent, "touch #{touch} ; rm -f #{donottouch}"

  step "test using puppet resource"
  on(agent, puppet_resource('exec', "test#{Time.new.to_i}",
                   "command='#{agent.touch(donottouch)}'",
                   "creates='#{touch}'")) do
    fail_test "looks like the thing executed, which it shouldn't" if
      stdout.include? 'executed successfully'
  end

  step "verify the file didn't get created the second time"
  on agent, "test -f #{donottouch}", :acceptable_exit_codes => [1]
end
