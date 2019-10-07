test_name "The Puppet service should be manageable with Puppet"

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # uses services from a running puppet-agent install
#
# This test is intended to ensure that the Puppet service can
# be directly managed by Puppet. See PUP-5053, PUP-5257, and RE-5574 for
# more context around circumstances that this can fail.
#

skip_test 'requires puppet service scripts from AIO agent package' if @options[:type] != 'aio'

require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

# Set service status before running other 'ensure' operations on it
def set_service_initial_status(host, service, status)
  step "Establishing precondition: #{service}: ensure => #{status}"
  ensure_service_on_host(host, service, {'ensure' => status})
end

# We want to test Puppet in the following conditions:
# 1) Starting, stopping and refreshing while the service is initially stopped
# 2) Starting, stopping and refreshing while the service is initially running
agents.each do |agent|

  ['puppet'].each do |service|
    # --- service management using `puppet apply` --- #
    step "#{service} service management using `puppet apply`"
    set_service_initial_status(agent, service, 'stopped')
    step "Starting the #{service} service: it should be running"
    ensure_service_on_host(agent, service, {'ensure' => 'running'})

    step "Stopping the #{service} service: it should be stopped"
    ensure_service_on_host(agent, service, {'ensure' => 'stopped'})

    ['stopped', 'running'].each do |status|
      step "Refreshing the #{service} service while it is #{status}: it should be #{status}"
      set_service_initial_status(agent, service, status)
      refresh_service_on_host(agent, service)
      assert_service_status_on_host(agent, service, {'ensure' => status}) # Status should not change after refresh

      # --- service management using `puppet resource` --- #
      step "#{service} service management using `puppet resource`"
      step "Starting the #{service} service while it is #{status}: it should be running"
      set_service_initial_status(agent, service, status)
      on(agent, puppet_resource('service', service, 'ensure=running'))
      assert_service_status_on_host(agent, service, {'ensure' => 'running'}) # Status should always be 'running' after starting

      step "Stopping the #{service} service while it is #{status}: it should be stopped"
      set_service_initial_status(agent, service, status)
      on(agent, puppet_resource('service', service, 'ensure=stopped'))
      assert_service_status_on_host(agent, service, {'ensure' => 'stopped'}) # Status should always be 'stopped' after stopping
    end
  end
end
