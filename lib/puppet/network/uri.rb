# frozen_string_literal: true

# This module holds funtions for network URI's
module Puppet::Network::Uri
  # Mask credentials in given URI or address as string. Resulting string will
  # contain '***' in place of password. It will only be replaced if actual
  # password is given.
  #
  # @param uri [URI|String] an uri or address to be masked
  # @return [String] a masked url
  def mask_credentials(uri)
    if uri.is_a? URI
      uri = uri.dup
    else
      uri = URI.parse(uri)
    end
    uri.password = '***' unless uri.password.nil?
    uri.to_s
  end
end
