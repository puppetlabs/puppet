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
    end
  end
end
