test_name "the pluginsync functionality should sync feature definitions" do

  tag 'audit:medium',
      'audit:integration'

  #
  # This test is intended to ensure that pluginsync syncs feature definitions to
  # the agents.  It checks the feature twice; once to make sure that it gets
  # loaded successfully during the run in which it was synced, and once to ensure
  # that it still gets loaded successfully during the subsequent run (in which it
  # should not be synced because the files haven't changed.)
  #

  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  module_name = 'superbogus'
  tmp_environment = mk_tmp_environment_with_teardown(master, 'sync')
  master_module_dir = "#{environmentpath}/#{tmp_environment}/modules"
  master_module_type_path = "#{master_module_dir}/#{module_name}/lib/puppet/type/"
  master_module_feature_path = "#{master_module_dir}/#{module_name}/lib/puppet/feature"
  on(master, "mkdir -p '#{master_module_dir}'")
  on(master, "mkdir -p '#{master_module_type_path}' '#{master_module_feature_path}'")

  master_module_type_file = "#{master_module_type_path}/#{module_name}.rb"
  master_module_type_content = <<-HERE
    module Puppet
      Type.newtype(:#{module_name}) do
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
  create_remote_file(master, master_module_type_file, master_module_type_content)

  master_module_feature_file = "#{master_module_feature_path}/#{module_name}.rb"
  master_module_feature_content = <<-HERE
    Puppet.features.add(:#{module_name}) do
      Puppet.info("#{module_name} feature being queried")
      true
    end
  HERE
  create_remote_file(master, master_module_feature_file, master_module_feature_content)
  on(master, "chmod 755 '#{master_module_type_file}' '#{master_module_feature_file}'")

  site_pp = <<-HERE
    #{module_name} { "This is the title of the #{module_name} type instance in site.pp":
      testfeature => "Hi.  I'm setting the testfeature property of #{module_name} here in site.pp",
    }
  HERE
  create_sitepp(master, tmp_environment, site_pp)

  step 'start the master' do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        agent_lib_dir             = agent.tmpdir('libdir')
        agent_module_type_file    = "#{agent_lib_dir}/puppet/type/#{module_name}.rb"
        agent_module_feature_file = "#{agent_lib_dir}/puppet/feature/#{module_name}.rb"

        step "verify that the module files don't exist on the agent path" do
          [agent_module_type_file, agent_module_feature_file].each do |file_path|
            if file_exists?(agent, file_path)
              fail_test("file should not exist on the agent yet: '#{file_path}'")
            end
          end
        end

        step 'run the agent and verify that it loaded the feature' do
          on(agent, puppet("agent -t --libdir='#{agent_lib_dir}' --server #{master} --environment '#{tmp_environment}'"),
             :acceptable_exit_codes => [2]) do |result|
            assert_match(/The value of the #{module_name} feature is: true/, result.stdout,
                         "Expected agent stdout to include confirmation that the feature was 'true'")
          end
        end

        step 'verify that the module files were synced down to the agent' do
          [agent_module_type_file, agent_module_feature_file].each do |file_path|
            unless file_exists?(agent, file_path)
              fail_test("Expected file to exist on the agent now: '#{file_path}'")
            end
          end
        end

        step 'run the agent again' do
          on(agent, puppet("agent -t --libdir='#{agent_lib_dir}' --server #{master} --environment '#{tmp_environment}'"),
             :acceptable_exit_codes => [2]) do |result|
            assert_match(/The value of the #{module_name} feature is: true/, result.stdout,
                         "Expected agent stdout to include confirmation that the feature was 'true'")
          end
        end
      end
    end
  end
end