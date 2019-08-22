test_name "PUP-9719 Windows First Agent run as SYSTEM sets cache file permissions correctly" do

  tag 'risk:medium',
    'audit:medium',
    'audit:integration' # exec resource succeeds when the `exit_code` parameter
  # is given a windows specific exit code and a exec
  # returns that exit code, ie. it either correctly matches
  # exit_code parameter to returned exit code, or ignores both (;

  confine :to, :platform => 'windows'

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  agents.each do |agent|
    statedir = on(agent, puppet('config print statedir')).stdout.chomp
    client_datadir = on(agent, puppet('config print client_datadir')).stdout.chomp

    teardown do
      on agent, "schtasks /delete /tn PuppetSystemRun /F"
      on agent, "rm -rf #{statedir}/*"
      on agent, "rm -rf #{client_datadir}/catalog/*"
    end

    step "Clean the ProgramData cache directory first" do
      on agent, "rm -rf #{statedir}/*"
      on agent, "rm -rf #{client_datadir}/catalog/*"
    end

    step "Create and run a scheduled task on System Account." do
      on agent, "schtasks /create /tn PuppetSystemRun /RL HIGHEST /RU SYSTEM /F /SC ONCE /ST 23:59 /TR 'cmd /c \"%ProgramFiles%\\Puppet Labs\\Puppet\\bin\\puppet.bat\" agent -t >> c:\\Windows\\Temp\\Puppet-System-Run.log 2>&1'"
      on agent, "schtasks /run /tn PuppetSystemRun"
    end

    step "Wait for Puppet Agent run to complete" do
      last_puppet_run = statedir + "/last_run_summary.yaml"
      (trymax, try, last_wait, wait) = 10,1,2,3
      file_found = false
      while try <= trymax
        if file_exists?(agent, last_puppet_run)
          logger.info("Puppet run has completed")
          file_found = true
          break
        end
        @logger.warn "Wait for Puppet (SYSTEM) run to complete, Try #{try}, Trying again in #{wait} seconds"
        sleep wait
        (last_wait, wait) = wait, last_wait + wait
        try += 1
      end
      fail_test("Puppet Run (SYSTEM) didn't complete") unless file_found
    end

    step "Test that normal PA run under Administrator doesn't fail." do
      on agent, "cmd /c puppet agent -t", acceptable_exit_codes: [0]
    end
  end
end
