class Puppet::Network::RESTServer # :nodoc:
  @@routes = {}
  
  def self.register(*indirections)
    raise ArgumentError, "indirection names are required" if indirections.empty?
    indirections.flatten.each { |i| @@routes[i.to_sym] = true }
  end
  
  def self.unregister(*indirections)
    raise ArgumentError, "indirection names are required" if indirections.empty?
    indirections.flatten.each do |i|
      raise(ArgumentError, "indirection [%s] is not known" % i) unless @@routes[i.to_sym]
      @@routes.delete(i.to_sym)
    end
  end
  
  def self.reset
    self.unregister(@@routes.keys) unless @@routes.keys.empty?
  end
end
