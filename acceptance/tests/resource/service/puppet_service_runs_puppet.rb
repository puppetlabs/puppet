require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

test_name 'Starting the puppet service should successfully run puppet' do

  tag 'audit:high',
      'audit:acceptance'

  skip_test 'requires a server node to run puppet agent -t' unless master

  agents.each do |agent|
    statedir = on(agent, puppet('config', 'print', 'statedir')).stdout.chomp
    last_run_report = "#{statedir}/last_run_report.yaml"

    teardown do
      on(agent, puppet_resource('file', last_run_report, 'ensure=absent'))
    end

    step 'Ensure last_run_report.yaml is absent' do
      on(agent, puppet_resource('file', last_run_report, 'ensure=absent'))
    end

    step 'Ensure stop puppet service' do
      on(agent, puppet_resource('service', 'puppet', 'ensure=stopped'))
      assert_service_status_on_host(agent, 'puppet', {'ensure' => 'stopped'})
    end

    step 'Ensure start puppet service' do
      on(agent, puppet_resource('service', 'puppet', 'ensure=running'))
      assert_service_status_on_host(agent, 'puppet', {'ensure' => 'running'})
    end

    retry_params = {:max_retries => 10,
                    :retry_interval => 2}

    step 'Ensure last_run_report.yaml is created' do
      retry_on(agent, "test -e #{last_run_report}", retry_params)
    end
  end
end
