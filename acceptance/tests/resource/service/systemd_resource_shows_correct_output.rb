require 'puppet/acceptance/service_utils'
extend Puppet::Acceptance::ServiceUtils

test_name 'systemd service shows correct output when queried with "puppet resource"' do

  tag 'audit:high'

  package_name = {'el'     => 'httpd',
                  'centos' => 'httpd',
                  'fedora' => 'httpd',
                  'debian' => 'apache2',
                  'sles'   => 'apache2',
                  'ubuntu' => 'cron'}

  # This test ensures that 'puppet resource' output matches the system state
  confine :to, {}, agents.select { |agent| supports_systemd?(agent) }

  agents.each do |agent|
    platform = agent.platform.variant
    initial_state = on(agent, puppet_resource('service', package_name[platform])).stdout

    teardown do
      apply_manifest_on(agent, initial_state)
    end

    step "Setting ensure=stopped and enable=true" do
      on(agent, puppet_resource('service', package_name[platform], 'ensure=stopped', 'enable=true'))
    end

    step "Expect reported status to match system state" do
      on(agent, puppet_resource('service', package_name[platform], 'ensure=stopped', 'enable=true')) do
        assert_match(/ensure\s*=>\s*'stopped'/, stdout, "Expected '#{package_name[platform]}' service to appear as stopped")
        assert_match(/enable\s*=>\s*'true'/, stdout, "Expected '#{package_name[platform]}' service to appear as enabled")
      end
    end
  end
end

