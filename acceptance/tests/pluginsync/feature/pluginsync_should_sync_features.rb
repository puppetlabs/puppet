test_name "the pluginsync functionality should sync feature definitions"

#
# This test is intended to ensure that pluginsync syncs feature definitions to the agents.  It checks the feature
# twice; once to make sure that it gets loaded successfully during the run in which it was synced, and once to
# ensure that it still gets loaded successfully during the subsequent run (in which it should not be synced because
# the files haven't changed.)
#


require 'puppet/acceptance/temp_file_utils'

extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()

all_tests_passed = false


###############################################################################
# BEGIN TEST LOGIC
###############################################################################

# create some vars to point to the directories that we're going to point the master/agents at
test_identifier = "pluginsync_should_sync_features"
master_module_dir = "master_modules"
agent_lib_dir = "agent_lib"

module_name = "superbogus"

# here we create a custom type, which basically doesn't do anything except for test the value of
# our custom feature and write the result to a file
agent_module_type_file = "#{agent_lib_dir}/puppet/type/#{module_name}.rb"
master_module_type_file = "#{master_module_dir}/#{module_name}/lib/puppet/type/#{module_name}.rb"
master_module_type_content = <<HERE
module Puppet
  newtype(:#{module_name}) do
    newparam(:name) do
      isnamevar
    end

    newproperty(:testfeature) do
      def sync
        Puppet.info("The value of the #{module_name} feature is: \#{Puppet.features.#{module_name}?}")
      end
      def retrieve
        :absent
      end
      def insync?(is)
        false
      end
    end
  end
end
HERE

# here is our custom feature... it always returns true
agent_module_feature_file = "#{agent_lib_dir}/puppet/feature/#{module_name}.rb"
master_module_feature_file = "#{master_module_dir}/#{module_name}/lib/puppet/feature/#{module_name}.rb"
master_module_feature_content = <<HERE
Puppet.features.add(:#{module_name}) do
  Puppet.info("#{module_name} feature being queried")
  true
end
HERE


# manifest file for the master, does nothing but instantiate our custom type
master_manifest_dir = "master_manifest"
master_manifest_file = "#{master_manifest_dir}/site.pp"
master_manifest_content = <<HERE
#{module_name} { "This is the title of the #{module_name} type instance in site.pp":
    testfeature => "Hi.  I'm setting the testfeature property of #{module_name} here in site.pp",
}
HERE


# for convenience we build up a list of all of the files we are expecting to deploy on the master
all_master_files = [
    [master_module_feature_file, 'feature'],
    [master_module_type_file, 'type'],
    [master_manifest_file, 'manifest']
]

# for convenience we build up a list of all of the files we are expecting to deploy on the agents
all_agent_files = [
    [agent_module_feature_file, 'feature'],
    [agent_module_type_file, 'type']
]

# the command line args we'll pass to the agent each time we call it
agent_args = "--trace --libdir=\"%s\" --pluginsync --no-daemonize --verbose " +
    "--onetime --test --server #{master}"
# legal exit codes whenever we run the agent
#  we need to allow exit code 2, which means "changes were applied" on the agent
agent_exit_codes = [0, 2]

# this begin block is here for handling temp file cleanup via an "ensure" block at the very end of the
# test.
begin

  # copy all the files to the master
  step "write our simple module out to the master" do
    create_test_file(master, master_module_type_file, master_module_type_content, :mkdirs => true)
    create_test_file(master, master_module_feature_file, master_module_feature_content, :mkdirs => true)
    create_test_file(master, master_manifest_file, master_manifest_content, :mkdirs => true)
  end

  step "verify that the module and manifest files exist on the master" do
    all_master_files.each do |file_path, desc|
      unless test_file_exists?(master, file_path) then
        fail_test("Failed to create #{desc} file '#{get_test_file_path(master, file_path)}' on master")
      end
    end
  end

  step "start the master" do

    with_master_running_on(master,
               "--manifest=\"#{get_test_file_path(master, master_manifest_file)}\" " +
               "--modulepath=\"#{get_test_file_path(master, master_module_dir)}\" " +
               "--autosign true --pluginsync") do

      # the module files shouldn't exist on the agent yet because they haven't been synced
      step "verify that the module files don't exist on the agent path" do
        agents.each do |agent|
          all_agent_files.each do |file_path, desc|
            if test_file_exists?(agent, file_path) then
              fail_test("#{desc} file already exists on agent: '#{get_test_file_path(agent, file_path)}'")
            end
          end
        end
      end


      step "run the agent and verify that it loaded the feature" do
        agents.each do |agent|
          run_agent_on(agent, agent_args % get_test_file_path(agent, agent_lib_dir),
                       :acceptable_exit_codes => agent_exit_codes) do
            assert_match(/The value of the #{module_name} feature is: true/, result.stdout,
              "Expected agent stdout to include confirmation that the feature was 'true'")
          end
        end
      end

      step "verify that the module files were synced down to the agent" do
        agents.each do |agent|
          all_agent_files.each do |file_path, desc|
            unless test_file_exists?(agent, file_path) then
              fail_test("Expected #{desc} file not synced to agent: '#{get_test_file_path(agent, file_path)}'")
            end
          end
        end
      end

      step "run the agent again" do
        agents.each do |agent|
          run_agent_on(agent, agent_args % get_test_file_path(agent, agent_lib_dir),
                          :acceptable_exit_codes => agent_exit_codes) do
            assert_match(/The value of the #{module_name} feature is: true/, result.stdout,
                         "Expected agent stdout to include confirmation that the feature was 'true'")
          end
        end
      end

      #TODO: was thinking about putting in a check for the timestamps on the files (maybe add a method for that to
      # the framework?) to verify that they didn't get re-synced, but it seems like more trouble than it's worth
      # at the moment.
      #step "verify that the module files were not re-synced" do
      #  fail_test("NOT YET IMPLEMENTED: verify that the module files were not re-synced")
      #end

    end

    all_tests_passed = true

  end
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


