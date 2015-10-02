test_name "Puppet and Mcollective services should be manageable with Puppet"

confine :except, :platform => 'windows' # See MCO-727
confine :except, :platform => /centos-4|el-4/ # PUP-5257

#
# This test is intended to ensure that the Puppet and Mcollective services can
# be directly managed by Puppet. See PUP-5053, PUP-5257, and RE-5574 for
# more context around circumstances that this can fail.
#

skip_test 'requires puppet and mcollective service scripts from AIO agent package' if @options[:type] != 'aio'

require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

# Set service status before running other 'ensure' operations on it
def set_service_initial_status(host, service, status)
  step "Establishing precondition: #{service}: ensure => #{status}"
  ensure_service_on_host(host, service, 'ensure', status)
  assert_service_status_on_host(host, service, status)
end

# We want to test Puppet and Mcollective in the following conditions:
# 1) Starting, stopping and refreshing while the service is initially stopped
# 2) Starting, stopping and refreshing while the service is initially running
agents.each do |agent|
  ['puppet', 'mcollective'].each do |service|
    ['stopped', 'running'].each do |status|
      # --- service management using `puppet apply` --- #
      step "#{service} service management using `puppet apply`"
      step "Starting the #{service} service while it is #{status}: it should be running"
      set_service_initial_status(agent, service, status)
      ensure_service_on_host(agent, service, 'ensure', 'running')
      assert_service_status_on_host(agent, service, 'running') # Status should always be 'running' after starting

      step "Stopping the #{service} service while it is #{status}: it should be stopped"
      set_service_initial_status(agent, service, status)
      ensure_service_on_host(agent, service, 'ensure', 'stopped')
      assert_service_status_on_host(agent, service, 'stopped') # Status should always be 'stopped' after stopping

      step "Refreshing the #{service} service while it is #{status}: it should be #{status}"
      set_service_initial_status(agent, service, status)
      refresh_service_on_host(agent, service)

      # The Solaris service provider currently doesn't wait for the Puppet service to finish
      # restarting before returning from the run. Remove this check when resolved.
      if agent.platform.variant =~ /solaris/ && service == 'puppet' && status == 'running'
        expect_failure('Expected test to fail due to PUP-5262') do
          assert_service_status_on_host(agent, service, status)
        end
      else
        assert_service_status_on_host(agent, service, status) # Status should not change after refresh
      end

      # --- service management using `puppet resource` --- #
      step "#{service} service management using `puppet resource`"
      step "Starting the #{service} service while it is #{status}: it should be running"
      set_service_initial_status(agent, service, status)
      on(agent, puppet_resource('service', service, 'ensure=running'))
      assert_service_status_on_host(agent, service, 'running') # Status should always be 'running' after starting

      step "Stopping the #{service} service while it is #{status}: it should be stopped"
      set_service_initial_status(agent, service, status)
      on(agent, puppet_resource('service', service, 'ensure=stopped'))
      assert_service_status_on_host(agent, service, 'stopped') # Status should always be 'stopped' after stopping
    end
  end
end
