# frozen_string_literal: true

require_relative '../puppet/http'
require_relative '../puppet/facter_impl'
require 'singleton'

# Provides access to runtime implementations.
#
# @api private
class Puppet::Runtime
  include Singleton

  def initialize
    @runtime_services = {
      http: proc do
        klass = Puppet::Network::HttpPool.http_client_class
        if klass == Puppet::Network::HTTP::Connection
          Puppet::HTTP::Client.new
        else
          Puppet::HTTP::ExternalClient.new(klass)
        end
      end,
      facter: proc { Puppet::FacterImpl.new }
    }
  end
  private :initialize

  # Loads all runtime implementations.
  #
  # @return Array[Symbol] the names of loaded implementations
  # @api private
  def load_services
    @runtime_services.keys.each { |key| self[key] }
  end

  # Get a runtime implementation.
  #
  # @param name [Symbol] the name of the implementation
  # @return [Object] the runtime implementation
  # @api private
  def [](name)
    service = @runtime_services[name]
    raise ArgumentError, "Unknown service #{name}" unless service

    if service.is_a?(Proc)
      @runtime_services[name] = service.call
    else
      service
    end
  end

  # Register a runtime implementation.
  #
  # @param name [Symbol] the name of the implementation
  # @param impl [Object] the runtime implementation
  # @api private
  def []=(name, impl)
    @runtime_services[name] = impl
  end

  # Clears all implementations. This is used for testing.
  #
  # @api private
  def clear
    initialize
  end
end
