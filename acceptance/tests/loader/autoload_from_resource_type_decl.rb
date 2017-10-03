test_name 'C100303: Resource type statement triggered auto-loading works both with and without generated types' do
  tag 'risk:medium'

  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/agent_fqdn_utils'
  extend Puppet::Acceptance::AgentFqdnUtils

  # create the file and make sure its empty and accessible by everyone
  def empty_execution_log_file(host, path)
    create_remote_file(host, path, '')
    on(host, "chmod 777 '#{path}'")
  end

  app_type               = File.basename(__FILE__, '.*')
  tmp_environment        = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath = "#{environmentpath}/#{tmp_environment}"

  relative_type_dir  = 'modules/one/lib/puppet/type'
  relative_type_path = "#{relative_type_dir}/type_tst.rb"

  execution_log = {}
  execution_log[agent_to_fqdn(master)] = master.tmpfile('master_autoload_resource')
  agents.each do |agent|
    execution_log[agent_to_fqdn(agent)] = agent.tmpfile('agent_autoload_resource')
  end

  teardown do
    on(master, "rm -f '#{execution_log[agent_to_fqdn(master)]}'")
    agents.each do |agent|
      on(agent, "rm -f '#{execution_log[agent_to_fqdn(agent)]}'")
    end
  end

  step 'create custom type' do
    on(master, "mkdir -p '#{fq_tmp_environmentpath}/#{relative_type_dir}'")

    # create a custom type that will write out to a different file on each agent
    # this way we can verify whether the newtype code was executed on each system
    custom_type = <<-END
    Puppet::Type.newtype(:type_tst) do
      newparam(:name, :namevar => true) do
        fqdn = Facter.value(:fqdn)
        if fqdn == '#{agent_to_fqdn(master)}'
          File.open("#{execution_log[agent_to_fqdn(master)]}", 'a+') { |f| f.puts("found_type_tst: " + Time.now.to_s) }
        end
    END
    agents.each do |agent|
      custom_type << <<-END
        if fqdn == '#{agent_to_fqdn(agent)}'
          File.open("#{execution_log[agent_to_fqdn(agent)]}", 'a+') { |f| f.puts("found_type_tst: " + Time.now.to_s) }
        end
      END
    end
    custom_type << <<-END
        Puppet.notice("found_type_tst")
      end
    end
    END
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_type_path}", custom_type)

    site_pp = <<-PP
    Resource['type_tst'] { 'found_type': }
    PP
    create_sitepp(master, tmp_environment, site_pp)
  end
  on(master, "chmod -R 755 '/tmp/#{tmp_environment}'")

  # when the agent does its run, the newtype is executed on both the agent and master nodes
  # so we should see a message in the execution log file on the agent and the master
  agents.each do |agent|
    with_puppet_running_on(master, {}) do

      empty_execution_log_file(master, execution_log[agent_to_fqdn(master)])
      empty_execution_log_file(agent, execution_log[agent_to_fqdn(agent)])

      on(agent, puppet("agent -t --server #{master.hostname} --environment '#{tmp_environment}'")) do |puppet_result|
        assert_match(/\/File\[.*\/type_tst.rb\]\/ensure: defined content as/, puppet_result.stdout,
                     'Expected to see defined content message for type: type_tst')
        assert_match(/Notice: found_type_tst/, puppet_result.stdout, 'Expected to see the notice from the new type: type_tst')
      end

      on(master, "cat '#{execution_log[agent_to_fqdn(master)]}'") do |cat_result|
        assert_match(/found_type_tst:/, cat_result.stdout,
                     "Expected to see execution log entry on master #{agent_to_fqdn(master)}")
      end
      on(agent, "cat '#{execution_log[agent_to_fqdn(agent)]}'") do |cat_result|
        assert_match(/found_type_tst:/, cat_result.stdout,
                     "Expected to see execution log entry on agent #{agent_to_fqdn(agent)}")
      end
    end
  end

  # when generating the pcore the newtype should only be run on the master node
  step 'generate pcore files' do
    # start with an empty execution log
    empty_execution_log_file(master, execution_log[agent_to_fqdn(master)])
    agents.each do |agent|
      empty_execution_log_file(agent, execution_log[agent_to_fqdn(agent)])
    end

    on(master, puppet("generate types --environment '#{tmp_environment}'")) do |puppet_result|
      assert_match(/Notice: Generating '\/.*\/type_tst\.pp' using 'pcore' format/, puppet_result.stdout,
                   'Expected to see Generating message for type: type_tst')
      assert_match(/Notice: found_type_tst/, puppet_result.stdout, 'Expected to see log entry on master ')
    end

    # we should see a log entry on the master node
    on(master, "cat '#{execution_log[agent_to_fqdn(master)]}'") do |cat_result|
      assert_match(/found_type_tst:/, cat_result.stdout,
                   "Expected to see execution log entry on master #{agent_to_fqdn(master)}")
    end

    # we should not see any log entries on any of the agent nodes
    agents.each do |agent|
      next if agent == master
      on(agent, "cat '#{execution_log[agent_to_fqdn(agent)]}'") do |cat_result|
        assert_empty(cat_result.stdout.chomp, "Expected execution log file to be empty on agent node #{agent_to_fqdn(agent)}")
      end
    end
  end

  empty_execution_log_file(master, execution_log[agent_to_fqdn(master)])
  agents.each do |agent|
    next if agent == master
    empty_execution_log_file(agent, execution_log[agent_to_fqdn(agent)])

    # this test is relying on the beaker helper with_puppet_running_on() to restart the server
    # Compilation should now work using the generated types,
    # so we should only see a log entry on the agent node and nothing on the master node
    with_puppet_running_on(master, {}) do
      on(agent, puppet("agent -t --server #{master.hostname} --environment '#{tmp_environment}'"),
         :acceptable_exit_codes => 0) do |puppet_result|
        assert_match(/Notice: found_type_tst/, puppet_result.stdout, 'Expected to see output from new type: type_tst')
      end
    end

    on(agent, "cat '#{execution_log[agent_to_fqdn(agent)]}'") do |cat_result|
      assert_match(/found_type_tst:/, cat_result.stdout,
                   "Expected to see an execution log entry on agent #{agent_to_fqdn(agent)}")
    end
  end

  on(master, "cat '#{execution_log[agent_to_fqdn(master)]}'") do |cat_result|
    assert_empty(cat_result.stdout.chomp, "Expected master execution log to be empty #{agent_to_fqdn(master)}")
  end
end
