test_name "should create symlink"
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

def message
  'hello world'
end

def reset_link_and_target(agent, link, target)
  step "clean up the system before we begin"
  on agent, "rm -rf #{target} #{link}"
  on agent, "echo '#{message}' > #{target}"
end

def verify_symlink(agent, link, target)
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
end

agents.each do |agent|
  if agent.platform.variant == 'windows'
    # symlinks are supported only on Vista+ (version 6.0 and higher)
    on agent, facter('kernelmajversion') do
      skip_test "Test not supported on this platform" if stdout.chomp.to_f < 6.0
    end
  end

  link_file = agent.tmpfile("symlink-link")
  target_file = agent.tmpfile("symlink-target")
  link_dir = agent.tmpdir("dir_symlink-link")
  target_dir = agent.tmpdir("dir-symlink-target")

  reset_link_and_target(agent, link_file, target_file)
  reset_link_and_target(agent, link_dir, target_dir)

  step "verify we can create a symlink with puppet resource"
  on(agent, puppet_resource("file", "#{link_file}", "ensure=#{target_file}"))
  verify_symlink(agent, link_file, target_file)
  reset_link_and_target(agent, link_file, target_file)

  step "verify that 'links => manage' preserves a symlink"
  apply_manifest_on(agent, "file { '#{link_file}': ensure => link, target => '#{target_file}', links => manage }")
  verify_symlink(agent, link_file, target_file)
  reset_link_and_target(agent, link_file, target_file)

  step "verify that 'links => manage' and 'recurse => true' preserves links in a directory"
  on(agent, puppet_resource("file", target_dir, "ensure=directory"))
  reset_link_and_target(agent, link_dir, "#{target_dir}/symlink-target")
  apply_manifest_on(agent, "file { '#{link_dir}': ensure => directory, target => '#{target_dir}', links => manage, recurse => true }")
  verify_symlink(agent, "#{link_dir}/symlink-target", "#{target_dir}/symlink-target")

  step "clean up after the test run"
  on agent, "rm -rf #{target_file} #{link_file} #{target_dir} #{link_dir}"
end
