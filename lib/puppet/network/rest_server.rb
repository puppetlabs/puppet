class Puppet::Network::RESTServer # :nodoc:
  @@routes = {}
  @@listening = false
  
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
  
  def self.listening?
    @@listening
  end
  
  def self.listen
    raise "Cannot listen -- already listening" if @@listening
    @@listening = true
  end
  
  def self.unlisten
    raise "Cannot unlisten -- not currently listening" unless @@listening
    @@listening = false
  end
end
