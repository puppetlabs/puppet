# frozen_string_literal: true

module Puppet::Network
  module Authorization
    class << self
      # This method is deprecated and will be removed in a future release.
      def authconfigloader_class=(klass)
        @authconfigloader_class = klass
      end

      # Verify something external to puppet is authorizing REST requests, so
      # we don't fail insecurely due to misconfiguration.
      def check_external_authorization(method, path)
        if @authconfigloader_class.nil?
          message = "Forbidden request: #{path} (method #{method})"
          raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError.new(message, Puppet::Network::HTTP::Issues::FAILED_AUTHORIZATION)
        end
      end
    end
  end
end
