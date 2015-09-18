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

      # Alter the state of a service using puppet apply.
      # @param host [String] hostname.
      # @param service [String] name of the service.
      # @param property [String] name of the attribute to be changed.
      # @param value [String] value which the property should be set.
      # @return None
      def ensure_service_on_host(host, service, property, value)
        manifest = %Q{
          service { '#{service}':
            #{property} => '#{value}'
          }
        }
        # the process of creating the service will also start it
        # to avoid a flickering test from the race condition, this test will ensure
        # that the exit code is either
        #   2 => something changed, or
        #   0 => no change needed
        on host, puppet_apply(['--detailed-exitcodes', '--verbose']),
          {:stdin => manifest, :acceptable_exit_codes => [0, 2]}
        # ensure idempotency
        on host, puppet_apply(['--detailed-exitcodes', '--verbose']),
          {:stdin => manifest, :acceptable_exit_codes => [0]}
      end

      # Checks that the status of a service is as expected.
      # @param host [String] hostname.
      # @param service [String] name of the service.
      # @param expected_status [String] expected service status.
      # @return None
      def assert_service_status_on_host(host, service, expected_status)
        on(host, puppet_resource('service', service)) do
          assert_match(/ensure => '#{expected_status}'/, stdout, "Expected service #{service} to have ensure => #{expected_status}")
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
