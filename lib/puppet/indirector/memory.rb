require 'puppet/indirector/terminus'

# Manage a memory-cached list of instances.
class Puppet::Indirector::Memory < Puppet::Indirector::Terminus
  def initialize
    clear
  end

  def clear
    @instances = {}
  end

  def destroy(request)
    raise ArgumentError.new("Could not find #{request.key} to destroy") unless @instances.include?(request.key)
    @instances.delete(request.key)
  end

  def find(request)
    @instances[request.key]
  end

  def search(request)
    found_keys = @instances.keys.find_all { |key| key.include?(request.key) }
    found_keys.collect { |key| @instances[key] }
  end

  def head(request)
    not find(request).nil?
  end

  def save(request)
    @instances[request.key] = request.instance
  end
end
