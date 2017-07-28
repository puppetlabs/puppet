test_name "C4553 - agent --disable/--enable functionality should manage the agent lockfile properly"
confine :except, :platform => 'cisco_nexus' #See BKR-749

tag 'audit:integration', # lockfile uses the standard `vardir` location to store/query lockfile.
                         # The validation of the `vardir` at the OS level
                         # should be accomplished in another test.
    'audit:medium',
    'audit:refactor'     # This test should not require a master. Remove the use of `with_puppet_running_on`.

#
# This test is intended to ensure that puppet agent --enable/--disable
#  work properly, both in terms of complying with our public "API" around
#  lockfile semantics ( http://links.puppet.com/agent_lockfiles ), and
#  in terms of actually restricting or allowing new agent runs to begin.
#

require 'puppet/acceptance/temp_file_utils'

extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()
@all_tests_passed = false


###############################################################################
# BEGIN TEST LOGIC
###############################################################################

teardown do
  if @all_tests_passed then
    remove_temp_dirs()
  end
  agents.each do |agent|
    on(agent, puppet('agent', "--enable"))
  end
end

tuples = [
    ["reason not specified", false],
    ["I'm busy; go away.'", true]
]

with_puppet_running_on(master, {}) do
  tuples.each do |expected_message, explicitly_specify_message|
    step "disable the agent; specify message? '#{explicitly_specify_message}', message: '#{expected_message}'" do
      agents.each do |agent|
        if (explicitly_specify_message)
          on(agent, puppet('agent', "--disable \"#{expected_message}\""))
        else
          on(agent, puppet('agent', "--disable"))
        end

        agent_disabled_lockfile = "#{agent.puppet['vardir']}/state/agent_disabled.lock"
        unless file_exists?(agent, agent_disabled_lockfile) then
          fail_test("Failed to create disabled lock file '#{agent_disabled_lockfile}' on agent '#{agent}'")
        end
        lock_file_content = file_contents(agent, agent_disabled_lockfile)

        # This is a hack; we should parse the JSON into a hash, but I don't
        # think I have a library available from the acceptance test framework
        # that I can use to do that.  So I'm falling back to <gasp> regex.
        lock_file_content_regex = /"disabled_message"\s*:\s*"#{expected_message}"/
        unless lock_file_content =~ lock_file_content_regex
          fail_test("Disabled lock file contents invalid; expected to match '#{lock_file_content_regex}', got '#{lock_file_content}' on agent '#{agent}'")
        end
      end
    end

    step "attempt to run the agent (message: '#{expected_message}')" do
      agents.each do |agent|
        on(agent, puppet('agent', "--test --server #{master}"),
                     :acceptable_exit_codes => [1]) do
          disabled_regex = /administratively disabled.*'#{expected_message}'/
          unless result.stdout =~ disabled_regex
            fail_test("Unexpected output from attempt to run agent disabled; expecting to match '#{disabled_regex}', got '#{result.stdout}' on agent '#{agent}'") unless agent['locale'] == 'ja'
          end
        end
      end
    end

    step "enable the agent (message: '#{expected_message}')" do
      agents.each do |agent|

        agent_disabled_lockfile = "#{agent.puppet['vardir']}/state/agent_disabled.lock"
        on(agent, puppet('agent', "--enable"))
        if file_exists?(agent, agent_disabled_lockfile) then
          fail_test("Failed to remove disabled lock file '#{agent_disabled_lockfile}' on agent '#{agent}'")
        end
      end
    end

    step "verify that we can run the agent (message: '#{expected_message}')" do
      agents.each do |agent|
        on(agent, puppet('agent', "--test --server #{master}"))
      end
    end
  end # tuples block
end # with_puppet_running_on block

@all_tests_passed = true
