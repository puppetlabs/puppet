test_name 'the pluginsync functionality should sync app definitions, and they should be runnable afterwards' do

  tag 'audit:medium',
      'audit:integration'

  #
  # This test is intended to ensure that pluginsync syncs app definitions to the agents.
  # Further, the apps should be runnable on the agent after the sync has occurred.
  #
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  tmp_environment   = mk_tmp_environment_with_teardown(master, 'app')
  master_module_dir = "#{environmentpath}/#{tmp_environment}/modules"
  on(master, "mkdir -p '#{master_module_dir}'")

  teardown do
    on(master, "rm -rf '#{master_module_dir}'")
  end

  app_name   = "superbogus"
  app_desc   = "a simple application for testing application delivery via plugin sync"
  app_output = "Hello from the #{app_name} application"

  master_module_file_content = <<-HERE
require 'puppet/application'

class Puppet::Application::#{app_name.capitalize} < Puppet::Application

  def help
    <<-HELP

puppet-#{app_name}(8) -- #{app_desc}
========
    HELP
  end

  def main()
    puts("#{app_output}")
  end
end
  HERE

  # here we create a custom app, which basically doesn't do anything except
  # for print a hello-world message
  #
  master_module_app_path = "#{master_module_dir}/#{app_name}/lib/puppet/application"
  master_module_app_file = "#{master_module_app_path}/#{app_name}.rb"
  on(master, "mkdir -p '#{master_module_app_path}'")
  create_remote_file(master, master_module_app_file, master_module_file_content)
  on(master, "chmod 755 '#{master_module_app_file}'")

  step "start the master" do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|

        agent_lib_dir         = agent.tmpdir('agent_lib_sync')
        agent_module_app_file = "#{agent_lib_dir}/puppet/application/#{app_name}.rb"
        teardown do
          on(agent, "rm -rf '#{agent_lib_dir}'")
        end

        # the module files shouldn't exist on the agent yet because they haven't been synced
        step "verify that the module files don't exist on the agent path" do
          if file_exists?(agent, agent_module_app_file)
            fail_test("app file already exists on agent: '#{agent_module_app_file}'")
          end
        end

        step "run the agent" do
          on(agent, puppet("agent --libdir='#{agent_lib_dir}' --test --server #{master} --environment '#{tmp_environment}'"))
        end

        step "verify that the module files were synced down to the agent" do
          unless file_exists?(agent, agent_module_app_file)
            fail_test("The app file we expect was not not synced to agent: '#{agent_module_app_file}'")
          end
        end

        step "verify that the application shows up in help" do
          on(agent, PuppetCommand.new(:help, "--libdir='#{agent_lib_dir}'")) do |result|
            assert_match(/^\s+#{app_name}\s+#{app_desc}/, result.stdout)
          end
        end

        step "verify that we can run the application" do
          on(agent, PuppetCommand.new(:"#{app_name}", "--libdir='#{agent_lib_dir}'")) do |result|
            assert_match(/^#{app_output}/, result.stdout)
          end
        end
      end
    end
  end
end
