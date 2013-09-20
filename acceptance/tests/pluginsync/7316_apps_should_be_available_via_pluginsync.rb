test_name "the pluginsync functionality should sync app definitions, and they should be runnable afterwards"

#
# This test is intended to ensure that pluginsync syncs app definitions to the agents.
# Further, the apps should be runnable on the agent after the sync has occurred.
#

require 'puppet/acceptance/temp_file_utils'

extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()

all_tests_passed = false

###############################################################################
# BEGIN TEST LOGIC
###############################################################################

# create some vars to point to the directories that we're going to point the master/agents at
master_module_dir = "master_modules"
agent_lib_dir = "agent_lib"

app_name = "superbogus"
app_desc = "a simple %1$s for testing %1$s delivery via plugin sync"
app_output = "Hello from the #{app_name} %s"

master_module_file_content = {}

master_module_file_content["application"] = <<-HERE
require 'puppet/application'

class Puppet::Application::#{app_name.capitalize} < Puppet::Application

  def help
    <<-HELP

puppet-#{app_name}(8) -- #{app_desc % "application"}
========
    HELP
  end

  def main()
    puts("#{app_output % "application"}")
  end
end
HERE


# this begin block is here for handling temp file cleanup via an "ensure" block at the very end of the
# test.
begin

  modes = ["application"]

  modes.each do |mode|

    # here we create a custom app, which basically doesn't do anything except for print a hello-world message
    agent_module_app_file = "#{agent_lib_dir}/puppet/#{mode}/#{app_name}.rb"
    master_module_app_file = "#{master_module_dir}/#{app_name}/lib/puppet/#{mode}/#{app_name}.rb"


    # copy all the files to the master
    step "write our simple module out to the master" do
      create_test_file(master, master_module_app_file, master_module_file_content[mode], :mkdirs => true)
    end

    step "verify that the app file exists on the master" do
      unless test_file_exists?(master, master_module_app_file) then
        fail_test("Failed to create app file '#{get_test_file_path(master, master_module_app_file)}' on master")
      end
    end

    step "start the master" do
      with_master_running_on(master,
             "--modulepath=\"#{get_test_file_path(master, master_module_dir)}\" " +
             "--autosign true") do

        # the module files shouldn't exist on the agent yet because they haven't been synced
        step "verify that the module files don't exist on the agent path" do
          agents.each do |agent|
              if test_file_exists?(agent, agent_module_app_file) then
                fail_test("app file already exists on agent: '#{get_test_file_path(agent, agent_module_app_file)}'")
              end
          end
        end

        step "run the agent" do
          agents.each do |agent|
            run_agent_on(agent, "--trace --libdir=\"#{get_test_file_path(agent, agent_lib_dir)}\" " +
                                "--no-daemonize --verbose --onetime --test --server #{master}")
          end
        end

      end
    end

    step "verify that the module files were synced down to the agent" do
      agents.each do |agent|
        unless test_file_exists?(agent, agent_module_app_file) then
          fail_test("The app file we expect was not not synced to agent: '#{get_test_file_path(agent, agent_module_app_file)}'")
        end
      end
    end

    step "verify that the application shows up in help" do
      agents.each do |agent|
        on(agent, PuppetCommand.new(:help, "--libdir=\"#{get_test_file_path(agent, agent_lib_dir)}\"")) do
          assert_match(/^\s+#{app_name}\s+#{app_desc % mode}/, result.stdout)
        end
      end
    end

    step "verify that we can run the application" do
      agents.each do |agent|
        on(agent, PuppetCommand.new(:"#{app_name}", "--libdir=\"#{get_test_file_path(agent, agent_lib_dir)}\"")) do
          assert_match(/^#{app_output % mode}/, result.stdout)
        end
      end
    end

    step "clear out the libdir on the agents in preparation for the next test" do
      agents.each do |agent|
        on(agent, "rm -rf #{get_test_file_path(agent, agent_lib_dir)}/*")
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
