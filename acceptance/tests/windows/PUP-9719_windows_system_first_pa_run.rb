# frozen_string_literal: true

test_name 'PUP-9719 Windows First Agent run as SYSTEM sets cache file permissions correctly' do
  tag 'risk:medium',
      'audit:medium',
      'audit:integration'

  confine :to, platform: 'windows'

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  agents.each do |agent|
    statedir = on(agent, puppet('config print statedir')).stdout.chomp
    client_datadir = on(agent, puppet('config print client_datadir')).stdout.chomp

    teardown do
      on agent, 'schtasks /delete /tn PuppetSystemRun /F'
      on agent, "rm -rf #{statedir}/*"
      on agent, "rm -rf #{client_datadir}/catalog/*"
    end

    step 'Clean the ProgramData cache directory first' do
      on agent, "rm -rf #{statedir}/*"
      on agent, "rm -rf #{client_datadir}/catalog/*"
    end

    step 'Create and run a scheduled task on System Account.' do
      date_format = if agent['locale'] == 'ja'
                      '%Y/%m/%d'
                    else
                      '%m/%d/%Y'
                    end
      on agent, "schtasks /create /tn PuppetSystemRun /RL HIGHEST /RU SYSTEM /F /SC ONCE /SD #{(Date.today + 1).strftime(date_format)} /ST 23:59 /TR 'cmd /c puppet agent -t'"
      on agent, 'schtasks /run /tn PuppetSystemRun'
    end

    step 'Wait for Puppet Agent run to complete' do
      last_puppet_run = File.join(statedir, 'last_run_summary.yaml')
      trymax = 10
      try = 1
      last_wait = 2
      wait = 3
      file_found = false
      while try <= trymax
        if file_exists?(agent, last_puppet_run)
          logger.info('Puppet run has completed')
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
      on agent, 'cmd /c puppet agent -t --detailed-exitcodes', acceptable_exit_codes: [0]
    end
  end
end
