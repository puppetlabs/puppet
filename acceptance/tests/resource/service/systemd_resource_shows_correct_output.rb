require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

test_name 'systemd service shows correct output when queried with "puppet resource"' do

  tag 'audit:high'

  skip_test 'requires puppet service script from AIO agent package' if @options[:type] != 'aio'

  package_name = 'puppet'

  # This test ensures that 'puppet resource' output matches the system state
  confine :to, {}, agents.select { |agent| supports_systemd?(agent) }

  agents.each do |agent|
    initial_state = on(agent, puppet_resource('service', package_name)).stdout

    teardown do
      apply_manifest_on(agent, initial_state)
    end

    step "Setting ensure=stopped and enable=true" do
      on(agent, puppet_resource('service', package_name, 'ensure=stopped', 'enable=true'))
    end

    step "Expect reported status to match system state" do
      on(agent, puppet_resource('service', package_name, 'ensure=stopped', 'enable=true')) do
        assert_match(/ensure\s*=>\s*'stopped'/, stdout, "Expected '#{package_name}' service to appear as stopped")
        assert_match(/enable\s*=>\s*'true'/, stdout, "Expected '#{package_name}' service to appear as enabled")
      end
    end
  end
end

