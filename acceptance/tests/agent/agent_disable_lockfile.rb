test_name "the agent --disable/--enable functionality should manage the agent lockfile properly"

#
# This test is intended to ensure that puppet agent --enable/--disable
#  work properly, both in terms of complying with our public "API" around
#  lockfile semantics ( http://links.puppetlabs.com/agent_lockfiles ), and
#  in terms of actually restricting or allowing new agent runs to begin.
#


require 'puppet/acceptance/temp_file_utils'

extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()
all_tests_passed = false


###############################################################################
# BEGIN TEST LOGIC
###############################################################################


# this begin block is here for handling temp file cleanup via an "ensure" block at the very end of the
# test.
begin

  tuples = [
      ["reason not specified", false],
      ["I'm busy; go away.'", true]
  ]

  step "start the master" do
    with_master_running_on(master, "--autosign true") do

      tuples.each do |expected_message, explicitly_specify_message|

        step "disable the agent; specify message? '#{explicitly_specify_message}', message: '#{expected_message}'" do
          agents.each do |agent|
            if (explicitly_specify_message)
              run_agent_on(agent, "--disable \"#{expected_message}\"")
            else
              run_agent_on(agent, "--disable")
            end

            agent_disabled_lockfile = "#{agent['puppetvardir']}/state/agent_disabled.lock"
            unless file_exists?(agent, agent_disabled_lockfile) then
              fail_test("Failed to create disabled lock file '#{agent_disabled_lockfile}' on agent '#{agent}'")
            end
            lock_file_content = file_contents(agent, agent_disabled_lockfile)
            # This is a hack; we should parse the JSON into a hash, but I don't think I have a library available
            #  from the acceptance test framework that I can use to do that.  So I'm falling back to <gasp> regex.
            lock_file_content_regex = /"disabled_message"\s*:\s*"#{expected_message}"/
            unless lock_file_content =~ lock_file_content_regex
              fail_test("Disabled lock file contents invalid; expected to match '#{lock_file_content_regex}', got '#{lock_file_content}' on agent '#{agent}'")
            end
          end
        end

        step "attempt to run the agent (message: '#{expected_message}')" do
          agents.each do |agent|
            run_agent_on(agent, "--no-daemonize --verbose --onetime --test --server #{master}",
                         :acceptable_exit_codes => [1]) do
              disabled_regex = /administratively disabled.*'#{expected_message}'/
              unless result.stdout =~ disabled_regex
                fail_test("Unexpected output from attempt to run agent disabled; expecting to match '#{disabled_regex}', got '#{result.stdout}' on agent '#{agent}'")
              end
            end
          end
        end

        step "enable the agent (message: '#{expected_message}')" do
          agents.each do |agent|

            agent_disabled_lockfile = "#{agent['puppetvardir']}/state/agent_disabled.lock"
            run_agent_on(agent, "--enable")
            if file_exists?(agent, agent_disabled_lockfile) then
              fail_test("Failed to remove disabled lock file '#{agent_disabled_lockfile}' on agent '#{agent}'")
            end
          end

        step "verify that we can run the agent (message: '#{expected_message}')" do
          agents.each do |agent|
            run_agent_on(agent)
            end
          end
        end

      end
    end
  end

  all_tests_passed = true

ensure
  ##########################################################################################
  # Clean up all of the temp files created by this test.  It would be nice if this logic
  # could be handled outside of the test itself; I envision a stanza like this one appearing
  # in a very large number of the tests going forward unless it is handled by the framework.
  ##########################################################################################
  if all_tests_passed then
    remove_temp_dirs()
  end
end
