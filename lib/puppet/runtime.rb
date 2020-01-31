require 'puppet/http'
require 'singleton'

class Puppet::Runtime
  include Singleton

  def initialize
    @runtime_services = {
      'http' => proc { Puppet::HTTP::Client.new }
    }
  end
  private :initialize

  def [](name)
    service = @runtime_services[name]
    raise ArgumentError, "Unknown service #{name}" unless service

    if service.is_a?(Proc)
      @runtime_services[name] = service.call
    else
      service
    end
  end

  def []=(name, impl)
    @runtime_services[name] = impl
  end

  # for testing
  def clear
    initialize
  end
end
