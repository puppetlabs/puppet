test_name "should remove directory, but force required"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  target = agent.tmpdir("delete-dir")

  step "clean up the system before we begin"
  on agent, "rm -rf #{target} ; mkdir -p #{target}"

  step "verify we can't remove a directory without 'force'"
  on(agent, puppet_resource("file", target, 'ensure=absent')) do
    fail_test "didn't tell us that force was required" unless
      stdout.include? "Not removing directory; use 'force' to override" unless agent['locale'] == 'ja'
  end

  step "verify the directory still exists"
  on agent, "test -d #{target}"

  step "verify we can remove a directory with 'force'"
  on(agent, puppet_resource("file", target, 'ensure=absent', 'force=true'))

  step "verify that the directory is gone"
  on agent, "test -d #{target}", :acceptable_exit_codes => [1]
end
