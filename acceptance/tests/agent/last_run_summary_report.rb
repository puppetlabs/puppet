test_name "The 'last_run_summary.yaml' report has the right location and permissions" do
  tag 'audit:high'

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils
  
  agents.each do |agent|
    skip_test('This test does not work on Windows in japanese') if agent['platform'] =~ /windows/ && agent['locale'] == 'ja'

    custom_publicdir = agent.tmpdir('custom_public_dir')

    statedir = on(agent, puppet('config print statedir')).stdout.chomp
    fail_test("The 'statedir' config is not set!") if statedir.empty?

    publicdir = on(agent, puppet('config print publicdir')).stdout.chomp
    fail_test("The 'publicdir' config is not set!") if publicdir.empty?

    teardown do
      agent.rm_rf(custom_publicdir)
      agent.rm_rf("#{publicdir}/*") unless publicdir.empty?
      on(agent, puppet("config set publicdir #{publicdir}"))
    end

    step "Check if '#{publicdir}' was created during puppet installation" do
      on(agent, "ls #{publicdir}", :acceptable_exit_codes => [0])
    end

    step "Check if '#{publicdir}' has '0755' permissions" do
      if agent['platform'] =~ /windows/
        on(agent, "icacls #{publicdir}") do |result|
          # Linux 'Owner' permissions class equivalent
          assert_match(/BUILTIN\\Administrators:.*\(F\)/, result.stdout)

          # Known issue on Windows: 'C:\ProgramData\PuppetLabs\puppet' permissions are inherited
          # by its subfolders and it does not have any permissions for 'Everyone' (see 'PuppetAppDir'
          # in 'puppet-agent/resources/windows/wix/appdatafiles.wxs')
          # Below line should be added when solution is found:
          # assert_match(/Everyone:.*\(RX\)/, result.stdout)
        end
      else
        on(agent, "ls -al #{publicdir}") do |result|
          assert_match(/rwxr-xr-x.+\.$/, result.stdout)
        end
      end
    end

    step "Create the 'last_run_summary.yaml' report file by applying catalog" do
      on(agent, puppet('agent -t')) do |result|
        assert_match('Applied catalog', result.stdout)
      end
    end

    step "Check if the 'last_run_summary.yaml' report file created has '0644' permissions" do
      if agent['platform'] =~ /windows/
        on(agent, "icacls #{File.join(publicdir, 'last_run_summary.yaml')}") do |result|
          # Linux 'Owner' premissions class equivalent
          assert_match('Administrator:(R,W', result.stdout)
          # Linux 'Group' permissions class equivalent
          assert_match('None:(R)', result.stdout)
          # Linux 'Public' permissions class equivalent
          assert_match('Everyone:(R)', result.stdout)
        end
      else
        on(agent, "ls -al #{publicdir}") do |result|
          assert_match(/rw-r--r--.+last_run_summary\.yaml$/, result.stdout)
        end
      end
    end

    step "Check that '#{statedir}' exists and has no 'last_run_summary.yaml' file" do
      on(agent, "ls #{statedir}",:acceptable_exit_codes => [0]) do |result|
        assert_no_match(/last_run_summary.yaml/, result.stdout)
      end
    end
    
    step "Check that 'publicdir' can be reconfigured" do
      on(agent, puppet("config set publicdir #{custom_publicdir}"))
      on(agent, puppet('config print publicdir')) do |result|
        assert_match(custom_publicdir, result.stdout)
      end
    end

    step "Create a new 'last_run_summary.yaml' report file by applying catalog" do
      on(agent, puppet('agent -t')) do |result|
        assert_match('Applied catalog', result.stdout)
      end
    end

    step "Check if the 'last_run_summary.yaml' report file was created in the new location and still has '0644' permissions" do
      if agent['platform'] =~ /windows/
        on(agent, "icacls #{File.join(custom_publicdir, 'last_run_summary.yaml')}") do |result|
          # Linux 'Owner' premissions class equivalent
          assert_match('Administrator:(R,W', result.stdout)
          # Linux 'Group' permissions class equivalent
          assert_match('None:(R)', result.stdout)
          # Linux 'Public' permissions class equivalent
          assert_match('Everyone:(R)', result.stdout)
        end
      else
        on(agent, "ls -al #{custom_publicdir}") do |result|
          assert_match(/rw-r--r--.+last_run_summary\.yaml$/, result.stdout)
        end
      end
    end
  end
end
