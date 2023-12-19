# frozen_string_literal: true

require_relative '../../puppet/ssl'

module Puppet::SSL
  # The `keyword_init: true` option is no longer needed in Ruby >= 3.2
  SSLContext = Struct.new(
    :store,
    :cacerts,
    :crls,
    :private_key,
    :client_cert,
    :client_chain,
    :revocation,
    :verify_peer,
    keyword_init: true
  ) do
    def initialize(*)
      super
      self[:cacerts] ||= []
      self[:crls] ||= []
      self[:client_chain] ||= []
      self[:revocation] = true if self[:revocation].nil?
      self[:verify_peer] = true if self[:verify_peer].nil?
    end
  end
end
