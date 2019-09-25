class Puppet::Runtime
  include Singleton

  def initialize
    @runtime_services = {}
  end

  def [](name)
    service = @runtime_services[name]
    raise ArgumentError, "Unknown service #{name}" unless service
    service
  end

  def []=(name, impl)
    @runtime_services[name] = impl
  end
end
