test_name "C4553 - agent --disable/--enable functionality should manage the agent lockfile properly" do
  confine :except, platform: "cisco_nexus" # See BKR-749

  require "json"

  tag 'audit:integration', # lockfile uses the standard `vardir` location to store/query lockfile.
                           # The validation of the `vardir` at the OS level
                           # should be accomplished in another test.
      'audit:medium'

  #
  #  This test is intended to ensure that puppet agent --enable/--disable
  #  work properly.
  #

  require "puppet/acceptance/temp_file_utils"

  extend Puppet::Acceptance::TempFileUtils

  initialize_temp_dirs
  @all_tests_passed = false

  ###############################################################################
  # BEGIN TEST LOGIC
  ###############################################################################

  teardown do
    remove_temp_dirs if @all_tests_passed
    agents.each do |agent|
      on(agent, puppet("agent", "--enable"))
    end
  end

  fakemaster = ('a'..'z').to_a.shuffle[0,10].join

  tuples = [
    ["reason not specified", false],
    ["I'm busy; go away.'", true]
  ]

  tuples.each do |expected_message, explicitly_specify_message|
    agents.each do |agent|
      step "disable the agent; specify message? '#{explicitly_specify_message}', message: '#{expected_message}'" do
        if explicitly_specify_message
          on(agent, puppet("agent", "--disable \"#{expected_message}\""))
        else
          on(agent, puppet("agent", "--disable"))
        end

        agent_disabled_lockfile = "#{agent.puppet['vardir']}/state/agent_disabled.lock"
        assert(agent.file_exist?(agent_disabled_lockfile),
               "Failed to create disabled lock file '#{agent_disabled_lockfile}' on agent '#{agent}'")

        lock_file_content = file_contents(agent, agent_disabled_lockfile)

        file_lock_json = JSON.parse(lock_file_content)
        assert_equal(expected_message, file_lock_json["disabled_message"])
      end

      step "attempt to run disabled agent (message: '#{expected_message}')" do
        skip_test "unable to assert match in Japanese" if agent["locale"] == "ja"
        on(agent, puppet("agent", "--test --server #{fakemaster}"),
           acceptable_exit_codes: [1]) do |result|
          disabled_regex = /administratively disabled.*'#{expected_message}'/
          assert_match(disabled_regex, result.stdout)
        end
      end

      step "enable the agent (message: '#{expected_message}')" do
        agent_disabled_lockfile = "#{agent.puppet['vardir']}/state/agent_disabled.lock"
        on(agent, puppet("agent", "--enable"))
        assert_equal(agent.file_exist?(agent_disabled_lockfile), false,
                     "Failed to remove disabled lock file '#{agent_disabled_lockfile}' on agent '#{agent}'")
      end

      step "verify that agent is enabled (message: '#{expected_message}')" do
        # Agent should attempt to run, but fail to connect to fakemaster
        on(agent, puppet("agent", "--test --server #{fakemaster}"),
           acceptable_exit_codes: [1]) do |result|
          assert_match(/Failed to open TCP connection/, result.stdout)
        end
      end
    end
  end # tuples block

  @all_tests_passed = true
end
