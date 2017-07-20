test_name "tests that puppet correctly captures large and empty output."
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  testfile = agent.tmpfile('should_accept_large_output')

  # Generate >64KB file to exceed pipe buffer.
  lorem_ipsum = <<EOF
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna
aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint
occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
EOF
  create_remote_file(agent, testfile, lorem_ipsum*1024)

  apply_manifest_on(agent, "exec {'cat #{testfile}': path => ['/bin', '/usr/bin', 'C:/cygwin32/bin', 'C:/cygwin64/bin', 'C:/cygwin/bin'], logoutput => true}") do
    fail_test "didn't seem to run the command" unless
      stdout.include? 'executed successfully' unless agent['locale'] == 'ja'
    fail_test "didn't print output correctly" unless
      stdout.lines.select {|line| line =~ /\/returns:/}.count == 4097
  end

  apply_manifest_on(agent, "exec {'echo': path => ['/bin', '/usr/bin', 'C:/cygwin32/bin', 'C:/cygwin64/bin', 'C:/cygwin/bin'], logoutput => true}") do
    fail_test "didn't seem to run the command" unless
      stdout.include? 'executed successfully' unless agent['locale'] == 'ja'
  end
end
