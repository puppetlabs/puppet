test_name "should be able to handle fifo files when recursing"
tag 'audit:high',
    'audit:acceptance'
confine :except, :platform => /windows/

def ensure_owner_recursively_manifest(path, owner_value)
  return <<-MANIFEST
  file { "#{path}":
    ensure  => present,
    recurse => true,
    owner   => #{owner_value}
  }
  MANIFEST
end

agents.each do |agent|
  initial_owner = ''
  random_user = "pl#{rand(999).to_i}"

  tmp_path = agent.tmpdir("tmpdir")
  fifo_path = "#{tmp_path}/myfifo"

  teardown do
    agent.rm_rf(tmp_path)
  end

  step "create fifo file" do
    on(agent, "mkfifo #{fifo_path}")
    on(agent, puppet("resource user #{random_user} ensure=absent"))
  end

  step "check that fifo file got created" do
    on(agent, "ls -l #{fifo_path}") do |result|
      assert(result.stdout.start_with?('p'))
      initial_owner = result.stdout.split[2]
    end
  end

  step "create a new user" do
    on(agent, puppet("resource user #{random_user} ensure=present"))
  end

  step "puppet ensures '#{random_user}' as owner of path" do
    apply_manifest_on(agent, ensure_owner_recursively_manifest(tmp_path, random_user), :acceptable_exit_codes => [0]) do |result|
      assert_match(/#{tmp_path}\]\/owner: owner changed '#{initial_owner}' to '#{random_user}'/, result.stdout)
      refute_match(/Error: .+ Failed to generate additional resources using ‘eval_generate’: Cannot manage files of type fifo/, result.stderr)
    end
  end

  step "check that given file is still a fifo" do
    on(agent, "ls -l #{fifo_path}") do |result|
      assert(result.stdout.start_with?('p'))
    end
  end

  step "check ownership of fifo file" do
    on(agent, "ls -l #{fifo_path}") do |result|
      user = result.stdout.split[2]
      assert_equal(random_user, user)
    end
  end

  step "check ownership of tmp folder" do
    on(agent, "ls -ld #{tmp_path}") do |result|
      user = result.stdout.split[2]
      assert_equal(random_user, user)
    end
  end
end
