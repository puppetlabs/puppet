test_name "Binary Diff Output of Content Attribute" do
  tag 'audit:high',
      'audit:acceptance'

  # cannot test binary diff on windows2012r2_ja-64-1
  # Error: Could not write report for afire-lien.delivery.puppetlabs.net at C:/ProgramData/PuppetLabs/puppet/cache/reports/afire-lien.delivery.puppetlabs.net/201912041455.yaml: anchor value must contain alphanumerical characters only
  # Error: Could not send report: anchor value must contain alphanumerical characters only
  confine :except, {}, hosts.select { |host| host[:platform]=~ /windows/ && host[:locale] == 'ja' }

  sha256 = Digest::SHA256.new
  agents.each do |agent|
    step 'When handling binary files' do
      target = agent.tmpfile('content_binary_file_test')
      initial_bin_data="\xc7\xd1\xfc\x84"
      initial_base64_data=Base64.encode64(initial_bin_data).chomp
      initial_sha_checksum = sha256.hexdigest(initial_bin_data)
      updated_bin_data="\xc7\xd1\xfc\x85"
      updated_base64_data=Base64.encode64(updated_bin_data).chomp
      updated_sha_checksum = sha256.hexdigest(updated_bin_data)
      on agent, puppet('config', 'set', 'diff', 'diff')

      agent_default_external_encoding=nil
      on(agent, "#{ruby_command(agent)} -e \"puts Encoding.default_external\"") do
        agent_default_external_encoding=stdout.chomp
      end

      if agent_default_external_encoding && agent_default_external_encoding != Encoding.default_external
        begin
          initial_bin_data=initial_bin_data.force_encoding(agent_default_external_encoding).encode(Encoding.default_external)
          updated_bin_data=updated_bin_data.force_encoding(agent_default_external_encoding).encode(Encoding.default_external)
        rescue Encoding::InvalidByteSequenceError
          #depending on agent_default_external_encoding, the conversion may fail, but this should not be a problem
        end
      end

      teardown do
        on agent, "rm -f #{target}"
      end

      step 'Ensure the test environment is clean' do
        on agent, "rm -f #{target}"
      end

      step 'Create binary file using content' do
        manifest = "file { '#{target}': content => Binary('#{initial_base64_data}'), ensure => present , checksum => 'sha256'}"

        on(agent, puppet('apply'), :stdin => manifest) do
          assert_match(/ensure: defined content as '{sha256}#{initial_sha_checksum}'/, stdout, "#{agent}: checksum of binary file not matched")
        end
      end

      step 'Update existing binary file content' do
        manifest = "file { '#{target}': content => Binary('#{updated_base64_data}'), ensure => present , checksum => 'sha256'}"

        on(agent, puppet('apply','--show_diff'), :stdin => manifest) do
          assert_match(/content: content changed '{sha256}#{initial_sha_checksum}' to '{sha256}#{updated_sha_checksum}'/, stdout, "#{agent}: checksum of binary file not matched after update")
          refute_match(/content: Received a Log attribute with invalid encoding:/, stdout, "#{agent}: Received a Log attribute with invalid encoding")
          if initial_bin_data.valid_encoding? && updated_bin_data.valid_encoding?
            assert_match(/^- ?#{initial_bin_data}$/, stdout, "#{agent}: initial utf-8 data not found in binary diff")
            assert_match(/^\+ ?#{updated_bin_data}$/, stdout, "#{agent}: updated utf-8 data not found in binary diff")
          else
            assert_match(/Binary files #{target} and .* differ/, stdout, "#{agent}: Binary file diff notice not matched")
          end
        end
      end
    end
  end
end
