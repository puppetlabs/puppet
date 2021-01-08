test_name "Puppet facts diff should show inconsistency between facter 3 and facter 4 outputs"

tag 'audit:high',
    'audit:integration'   # The facter acceptance tests should be acceptance.
                          # However, the puppet face merely needs to interact with libfacter.
                          # So, this should be an integration test.
#
# This test is intended to ensure that puppet facts diff
# displays inconsistencies between Facter 3 and Facter 4 outputs
#

agents.each do |agent|

  on agent, facter('aio_agent_version') do
    # `puppet facts diff` is only supported only on puppet version <= 7.x
    skip_test "Test not supported on this platform" if stdout.chomp.to_f > 7.0
  end

  step 'running puppet facts diff' do
    step 'with facter-ng enabled' do
      # enable facterng in settings
      on agent, puppet('config', 'set', 'facterng', 'true')
      on agent, puppet('facts', 'diff') do
        assert_match(/Already using Facter 4. To use `puppet facts diff` remove facterng from the .conf file or run `puppet config set facterng false`./, stderr, "`puppet facts diff` should not be available with Facter 4")
      end
    end

    step 'with facter-ng disabled' do
      # enable facterng in settings
      on agent, puppet('config', 'set', 'facterng', 'false')
      on agent, puppet('facts', 'diff') do |result|
        assert(result.exit_code == 0, "puppet facts diff failed or didn't exit properly: (#{result.exit_code})")
      end
    end
  end
end
