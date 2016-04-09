require 'puppet/acceptance/common_utils'

module Puppet
  module Acceptance
    module ServiceUtils

      # Return whether a host supports the systemd provider.
      # @param host [String] hostname
      # @return [Boolean] whether the systemd provider is supported.
      def supports_systemd? (host)
        # The Windows MSI doesn't put Puppet in the Ruby vendor or site dir, so loading it fails.
        return false if host.platform.variant == 'windows'
        ruby = Puppet::Acceptance::CommandUtils.ruby_command(host)
        suitable = on(host, "#{ruby} -e \"require 'puppet'; puts Puppet::Type.type(:service).provider(:systemd).suitable?\"" ).stdout.chomp
        suitable == "true" ? true : false
      end

      # Construct manifest ensuring service status.
      # @param service [String] name of the service
      # @param status [Hash] properties to set - can include 'ensure' and 'enable' keys.
      # @return [String] a manifest
      def service_manifest(service, status)
        ensure_status = "ensure => '#{status[:ensure]}'," if status[:ensure]
        enable_status = "enable => '#{status[:enable]}'," if status[:enable]
        %Q{
          service { '#{service}':
            #{ensure_status}
            #{enable_status}
          }
        }
      end

      # Alter the state of a service using puppet apply and assert that a change was logged.
      # Assumes the starting state is not the desired state.
      # @param host [String] hostname.
      # @param service [String] name of the service.
      # @param status [Hash] properties to set - can include 'ensure' and 'enable' keys.
      # @return None
      def ensure_service_change_on_host(host, service, status)
        # the process of creating the service will also start it
        # to avoid a flickering test from the race condition, this test will ensure
        # that the exit code is either
        #   2 => something changed, or
        #   0 => no change needed
        apply_manifest_on host, service_manifest(service, status), :acceptable_exit_codes => [0, 2] do
          assert_match(/Service\[#{service}\]\/ensure: ensure changed '\w+' to '#{status[:ensure]}'/, stdout, 'Service status change failed') if status[:ensure]
          assert_match(/Service\[#{service}\]\/enable: enable changed '\w+' to '#{status[:enable]}'/, stdout, 'Service enable change failed') if status[:enable]
        end
      end

      # Ensure the state of a service using puppet apply and assert that no change was logged.
      # Assumes the starting state is the ensured state.
      # @param host [String] hostname.
      # @param service [String] name of the service.
      # @param status [Hash] properties to set - can include 'ensure' and 'enable' keys.
      # @return None
      def ensure_service_idempotent_on_host(host, service, status)
        # ensure idempotency
        apply_manifest_on host, service_manifest(service, status) do
          assert_no_match(/Service\[#{service}\]\/ensure/, stdout, 'Service status not idempotent') if status[:ensure]
          assert_no_match(/Service\[#{service}\]\/enable/, stdout, 'Service enable not idempotent') if status[:enable]
        end
      end

      # Alter the state of a service using puppet apply, assert that it changed and change is idempotent.
      # Can set 'ensure' and 'enable'. Assumes the starting state is not the desired state.
      # @param host [String] hostname.
      # @param service [String] name of the service.
      # @param status [Hash] properties to set - can include 'ensure' and 'enable' keys.
      # @param block [Proc] optional: block to verify service state
      # @return None
      def ensure_service_on_host(host, service, status, &block)
        ensure_service_change_on_host(host, service, status)
        assert_service_status_on_host(host, service, status, &block)
        ensure_service_idempotent_on_host(host, service, status)
        assert_service_status_on_host(host, service, status, &block)
      end

      # Checks that the ensure and/or enable status of a service are as expected.
      # @param host [String] hostname.
      # @param service [String] name of the service.
      # @param status [Hash] properties to set - can include 'ensure' and 'enable' keys.
      # @param block [Proc] optional: block to verify service state
      # @return None
      def assert_service_status_on_host(host, service, status, &block)
        ensure_status = "ensure => '#{status[:ensure]}'" if status[:ensure]
        enable_status = "enable => '#{status[:enable]}'" if status[:enable]

        on host, puppet_resource('service', service) do
          assert_match(/'#{service}'.+#{ensure_status}.+#{enable_status}/m, stdout, "Service status does not match expectation #{status}")
        end

        # Verify service state on the system using a custom block
        if block
          yield block
        end
      end

      # Refreshes a service.
      # @param host [String] hostname.
      # @param service [String] name of the service to refresh.
      # @return None
      def refresh_service_on_host(host, service)
        refresh_manifest = %Q{
          service { '#{service}': }

          notify { 'Refreshing #{service}':
            notify => Service['#{service}'],
          }
        }

        apply_manifest_on(host, refresh_manifest)
      end
    end
  end
end
