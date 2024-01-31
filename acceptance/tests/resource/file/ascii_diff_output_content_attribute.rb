test_name "ASCII Diff Output of Content Attribute" do
  tag 'audit:high',
      'audit:acceptance'

  sha256 = Digest::SHA256.new
  agents.each do |agent|
    step 'When handling ASCII files' do
      target = agent.tmpfile('content_ASCII_file_test')
      initial_text = 'Initial Text'
      initial_text_sha_checksum = sha256.hexdigest(initial_text)
      updated_text = 'Updated Text'
      updated_text_sha_checksum = sha256.hexdigest(updated_text)
      on agent, puppet('config', 'set', 'diff', 'diff')

      step 'Ensure the test environment is clean' do
        on agent, "rm -f #{target}"
      end

      teardown do
        on agent, "rm -f #{target}"
      end

      step 'Create ASCII file using content' do
        manifest = "file { '#{target}': content => '#{initial_text}', ensure => present , checksum => 'sha256'}"

        on(agent, puppet('apply'), :stdin => manifest) do |result|
          assert_match(/ensure: defined content as '{sha256}#{initial_text_sha_checksum}'/, result.stdout, "#{agent}: checksum of ASCII file not matched")
        end
      end

      step 'Update existing ASCII file content' do
        manifest = "file { '#{target}': content => '#{updated_text}', ensure => present , checksum => 'sha256'}"

        on(agent, puppet('apply','--show_diff'), :stdin => manifest) do |result|
          assert_match(/content: content changed '{sha256}#{initial_text_sha_checksum}' to '{sha256}#{updated_text_sha_checksum}'/, result.stdout, "#{agent}: checksum of ASCII file not matched after update")
          assert_match(/^- ?#{initial_text}$/, result.stdout, "#{agent}: initial text not found in diff")
          assert_match(/^\+ ?#{updated_text}$/, result.stdout, "#{agent}: updated text not found in diff")
        end
      end
    end
  end
end
