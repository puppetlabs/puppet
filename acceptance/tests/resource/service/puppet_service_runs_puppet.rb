require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

test_name 'Starting the puppet service should successfully run puppet' do

  tag 'audit:high',
      'audit:acceptance'

  agents.each do |agent|
    step 'Ensure stop puppet service' do
      on(agent, puppet_resource('service', 'puppet', 'ensure=stopped'))
      assert_service_status_on_host(agent, 'puppet', {'ensure' => 'stopped'})
    end

    statedir = on(agent, puppet('config', 'print', 'statedir')).stdout.chomp
    mtime_cmd = "File.stat(\"#{statedir}/last_run_report.yaml\").mtime.to_i"
    last_run_time = on(agent, "env PATH=\"#{agent['privatebindir']}:${PATH}\" ruby -e 'puts #{mtime_cmd}'").stdout.chomp

    step 'Ensure start puppet service' do
      on(agent, puppet_resource('service', 'puppet', 'ensure=running'))
      assert_service_status_on_host(agent, 'puppet', {'ensure' => 'running'})
    end

    retry_params = {:max_retries => 10,
                    :retry_interval => 2}
    step 'Ensure last_run_report.yaml is updated' do
      retry_on(agent, "env PATH=\"#{agent['privatebindir']}:${PATH}\" ruby -e 'exit #{mtime_cmd} > #{last_run_time}'", retry_params)
    end
  end
end
