test_name 'PA-2191 - winruby fallsback to UTF8 for invalid CodePage' do
  confine :to, platform: 'windows'

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |host|

    initial_chcp_code = on(host, 'cmd.exe /c chcp').stdout.delete('^0-9')

    teardown do
      on(host, "cmd.exe /c chcp #{initial_chcp_code}")
    end

    step 'set an invalid Code Page and check if puppet can run' do
      on(host, 'cmd.exe /c chcp 720')
      begin
        on(host, puppet('--version'), acceptable_exit_codes: [0])
      rescue StandardError
        fail_test('Code Page 720 is invalid')
      end
    end
  end
end
