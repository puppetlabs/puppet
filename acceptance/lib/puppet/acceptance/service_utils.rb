require 'puppet/acceptance/common_utils'

module Puppet
  module Acceptance
    module ServiceUtils

      # Return whether a host supports the systemd provider.
      # @param host [String] hostname
      # @return [Boolean] whether the systemd provider is supported.
      def supports_systemd? (host)
        if host['platform'] =~ /windows/
          false
        else
          ruby = Puppet::Acceptance::CommandUtils.ruby_command(host)
          suitable = on(host, "#{ruby} -e \"require 'puppet'; puts Puppet::Type.type(:service).provider(:systemd).suitable?\"" ).stdout.chomp
          suitable == "true" ? true : false
        end
      end
    end
  end
end
