test_name "C98092 - a new resource should not be reported as a corrective change" do

  require 'yaml'
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/agent_fqdn_utils'
  extend Puppet::Acceptance::AgentFqdnUtils

  tag 'audit:medium',
      'audit:integration',
      'audit:refactor',    # Uses a server currently but is testing agent report
      'broken:images'

  test_file_name  = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, test_file_name)
  tmp_file        = {}

  agents.each do |agent|
    tmp_file[agent_to_fqdn(agent)] = agent.tmpfile(tmp_environment)
  end

  teardown do
    step 'clean out produced resources' do
      agents.each do |agent|
        if tmp_file.has_key?(agent_to_fqdn(agent)) && tmp_file[agent_to_fqdn(agent)] != ''
          on(agent, "rm '#{tmp_file[agent_to_fqdn(agent)]}'", :accept_all_exit_codes => true)
        end
      end
    end
  end

  step 'create file resource - site.pp to verify corrective change flag' do
    file_contents = 'this is a test'
    manifest      = <<-MANIFEST
    file { '#{environmentpath}/#{tmp_environment}/manifests/site.pp':
      ensure => file,
      content => '
    \$test_path = \$::fqdn ? #{tmp_file}
    file { \$test_path:
      content => @(UTF8)
        #{file_contents}
        | UTF8
    }
      ',
    }
    MANIFEST
    apply_manifest_on(master, manifest, :catch_failures => true)
  end

  step 'run agent(s)' do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        #Run agent once to create new File resource
        step 'Run agent once to create new File resource' do
          on(agent, puppet("agent -t --environment '#{tmp_environment}' --server #{master.hostname}"), :acceptable_exit_codes => 2)
        end

        #Verify the file resource is created
        step 'Verify the file resource is created' do
          on(agent, "cat '#{tmp_file[agent_to_fqdn(agent)]}'").stdout do |file_result|
            assert_equal(file_contents, file_result, 'file contents did not match accepted')
          end
        end
      end
    end
  end

  # Open last_run_report.yaml
  step 'Check report' do
    agents.each do |agent|
      on(agent, puppet('config print statedir')) do |command_result|
        report_path = command_result.stdout.chomp + '/last_run_report.yaml'
        on(agent, "cat '#{report_path}'").stdout do |report_contents|

          yaml_data = YAML::parse(report_contents)
          # Remove any Ruby class tags from the yaml
          yaml_data.root.each do |o|
            if o.respond_to?(:tag=) and o.tag != nil and o.tag.start_with?("!ruby")
              o.tag = nil
            end
          end
          report_yaml = yaml_data.to_ruby

          file_resource_details = report_yaml["resource_statuses"]["File[#{tmp_file[agent_to_fqdn(agent)]}]"]
          assert(file_resource_details.has_key?("corrective_change"), 'corrective_change key is missing')
          corrective_change_value = file_resource_details["corrective_change"]
          assert_equal(false, corrective_change_value, 'corrective_change flag should be false')
        end
      end
    end
  end

end
