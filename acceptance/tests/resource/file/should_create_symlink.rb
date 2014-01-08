test_name "should create symlink"

message = 'hello world'
agents.each do |agent|
  confine_block :to, :platform => 'windows' do
    # symlinks are supported only on Vista+ (version 6.0 and higher)
    on agents, facter('kernelmajversion') do
      skip_test "Test not supported on this plaform" if stdout.chomp.to_f < 6.0
    end
  end

  link = agent.tmpfile("symlink-link")
  target = agent.tmpfile("symlink-target")

  step "clean up the system before we begin"
  on agent, "rm -rf #{target} #{link}"
  on agent, "echo '#{message}' > #{target}"

  step "verify we can create a symlink"
  on(agent, puppet_resource("file", link, "ensure=#{target}"))

  step "verify the symlink was created"
  on agent, "test -L #{link} && test -f #{link}"
  step "verify the symlink points to a file"
  on agent, "test -f #{target}"

  step "verify the content is identical on both sides"
  on(agent, "cat #{link}") do
    fail_test "link missing content" unless stdout.include? message
  end
  on(agent, "cat #{target}") do
    fail_test "target missing content" unless stdout.include? message
  end

  step "clean up after the test run"
  on agent, "rm -rf #{target} #{link}"
end
