test_name "should be able to handle fifo files"
tag 'audit:high',
    'audit:acceptance'
confine :except, :platform => /windows/

def ensure_content_to_file_manifest(file_path, ensure_value)
  return <<-MANIFEST
  file { "#{file_path}":
    ensure => #{ensure_value},
    content => "Hello World"
  }
  MANIFEST
end

agents.each do |agent|
  tmp_path = agent.tmpdir("tmpdir")
  fifo_path = "#{tmp_path}/myfifo"

  teardown do
    agent.rm_rf(tmp_path)
  end

  step "create fifo" do
    on(agent, "mkfifo #{fifo_path}")
  end

  step "check that fifo got created" do
    on(agent, "ls -l #{fifo_path}") do |result|
      assert(result.stdout.start_with?('p'))
    end
  end

  step "puppet ensures given fifo is present" do
    apply_manifest_on(agent, ensure_content_to_file_manifest(fifo_path, 'present'), :acceptable_exit_codes => [2]) do
      assert_match(/Warning: .+ Ensure set to :present but file type is fifo so no content will be synced/, stderr)
    end
  end

  step "check that given file is still a fifo" do
    on(agent, "ls -l #{fifo_path}") do |result|
      assert(result.stdout.start_with?('p'))
    end
  end

  step "puppet ensures given fifo is a regular file" do
    apply_manifest_on(agent, ensure_content_to_file_manifest(fifo_path, 'file'), :acceptable_exit_codes => [0]) do
      assert_match(/Notice: .+\/myfifo\]\/ensure: defined content as '{/, stdout)
      refute_match(/Warning: .+ Ensure set to :present but file type is fifo so no content will be synced/, stderr)
    end
  end

  step "check that given fifo is now a regular file" do
    on(agent, "ls -l #{fifo_path}") do |result|
      assert(result.stdout.start_with?('-'))
    end
  end

  step "check that given file now has desired content" do
    on(agent, "cat #{fifo_path}") do |result|
      assert_equal('Hello World', result.stdout)
    end
  end
end
