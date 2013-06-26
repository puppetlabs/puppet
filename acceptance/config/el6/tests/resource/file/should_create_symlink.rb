test_name "should create symlink"
confine :except, :platform => 'windows'

message = 'hello world'
target  = "/tmp/test-#{Time.new.to_i}"
source  = "/tmp/test-#{Time.new.to_i}-source"

agents.each do |agent|
  step "clean up the system before we begin"
  on agent, "rm -rf #{target}"
  on agent, "echo '#{message}' > #{source}"

  step "verify we can create a symlink"
  on(agent, puppet_resource("file", target, "ensure=#{source}"))

  step "verify the symlink was created"
  on agent, "test -L #{target} && test -f #{target}"
  step "verify source file"
  on agent, "test -f #{source}"

  step "verify the content is identical on both sides"
  on(agent, "cat #{source}") do
    fail_test "source missing content" unless stdout.include? message
  end
  on(agent, "cat #{target}") do
    fail_test "target missing content" unless stdout.include? message
  end

  step "clean up after the test run"
  on agent, "rm -rf #{target} #{source}"
end
