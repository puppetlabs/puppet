test_name "the $libdir setting hook is called on startup"

require 'puppet/acceptance/temp_file_utils'

extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()
all_tests_passed = false

tag 'audit:medium',      # tests basic custom module/pluginsync handling?
    'audit:refactor',    # Use block style `test_namme`
    'audit:integration',
    'server'

###############################################################################
# BEGIN TEST LOGIC
###############################################################################

# create some vars to point to the directories that we're going to point the master/agents at
master_module_dir = "master_modules"
agent_var_dir = "agent_var"
agent_lib_dir = "#{agent_var_dir}/lib"

app_name = "superbogus"
app_desc = "a simple %1$s for testing %1$s delivery via plugin sync"
app_output = "Hello from the #{app_name} %s"

master_module_file_content = {}

master_module_face_content = <<-HERE
Puppet::Face.define(:#{app_name}, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "#{app_desc % "face"}"

  action(:foo) do
    summary "a test action defined in the test face in the main puppet lib dir"

    default
    when_invoked do |*args|
      puts "#{app_output % "face"}"
    end
  end

end
HERE

master_module_app_content = <<-HERE
require 'puppet/application/face_base'

class Puppet::Application::#{app_name.capitalize} < Puppet::Application::FaceBase
end

HERE

# this begin block is here for handling temp file cleanup via an "ensure" block
# at the very end of the test.
begin

  # here we create a custom app, which basically doesn't do anything except for
  # print a hello-world message
  agent_module_face_file = "#{agent_lib_dir}/puppet/face/#{app_name}.rb"
  master_module_face_file = "#{master_module_dir}/#{app_name}/lib/puppet/face/#{app_name}.rb"

  agent_module_app_file = "#{agent_lib_dir}/puppet/application/#{app_name}.rb"
  master_module_app_file = "#{master_module_dir}/#{app_name}/lib/puppet/application/#{app_name}.rb"

  # copy all the files to the master
  step "write our simple module out to the master" do
    create_test_file(master, master_module_app_file, master_module_app_content, :mkdirs => true)
    create_test_file(master, master_module_face_file, master_module_face_content, :mkdirs => true)
  end

  step "verify that the app file exists on the master" do
    unless test_file_exists?(master, master_module_app_file) then
      fail_test("Failed to create app file '#{get_test_file_path(master, master_module_app_file)}' on master")
    end
    unless test_file_exists?(master, master_module_face_file) then
      fail_test("Failed to create face file '#{get_test_file_path(master, master_module_face_file)}' on master")
    end
  end

  step "start the master" do
    basemodulepath = "#{get_test_file_path(master, master_module_dir)}"
    if master.is_pe?
      basemodulepath << ":#{master['sitemoduledir']}"
    end
    master_opts = {
      'main' => {
        'basemodulepath' => basemodulepath,
      },
      'master' => {
        'node_terminus' => 'plain',
      },
    }

    with_puppet_running_on master, master_opts do

      # the module files shouldn't exist on the agent yet because they haven't been synced
      step "verify that the module files don't exist on the agent path" do
        agents.each do |agent|
            if test_file_exists?(agent, agent_module_app_file) then
              fail_test("app file already exists on agent: '#{get_test_file_path(agent, agent_module_app_file)}'")
            end
            if test_file_exists?(agent, agent_module_face_file) then
              fail_test("face file already exists on agent: '#{get_test_file_path(agent, agent_module_face_file)}'")
            end
        end
      end

      step "run the agent" do
        agents.each do |agent|

          step "capture the existing ssldir, in case the default package puppet.conf sets it within vardir (rhel...)"
          agent_ssldir = on(agent, puppet('agent --configprint ssldir')).stdout.chomp

          on(agent, puppet('agent',
                           "--vardir=\"#{get_test_file_path(agent, agent_var_dir)}\" ",
                           "--ssldir=\"#{agent_ssldir}\" ",
                           "--trace  --test --server #{master}")
          )
        end
      end

    end
  end

  step "verify that the module files were synced down to the agent" do
    agents.each do |agent|
      unless test_file_exists?(agent, agent_module_app_file) then
        fail_test("Expected app file not synced to agent: '#{get_test_file_path(agent, agent_module_app_file)}'")
      end
      unless test_file_exists?(agent, agent_module_face_file) then
        fail_test("Expected face file not synced to agent: '#{get_test_file_path(agent, agent_module_face_file)}'")
      end
    end
  end

  step "verify that the application shows up in help" do
    agents.each do |agent|
      on(agent, PuppetCommand.new(:help, "--vardir=\"#{get_test_file_path(agent, agent_var_dir)}\"")) do
        assert_match(/^\s+#{app_name}\s+#{app_desc % "face"}/, result.stdout)
      end
    end
  end

  step "verify that we can run the application" do
    agents.each do |agent|
      on(agent, PuppetCommand.new(:"#{app_name}", "--vardir=\"#{get_test_file_path(agent, agent_var_dir)}\"")) do
        assert_match(/^#{app_output % "face"}/, result.stdout)
      end
    end
  end

  step "clear out the libdir on the agents in preparation for the next test" do
    agents.each do |agent|
      on(agent, "rm -rf '#{get_test_file_path(agent, agent_lib_dir)}/*'")
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
