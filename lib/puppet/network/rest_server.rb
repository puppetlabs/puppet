class Puppet::Network::RESTServer # :nodoc:
  attr_reader :server
  
  def initialize(args = {})
    raise(ArgumentError, "requires :server to be specified") unless args[:server]
    @routes = {}
    @listening = false
    @server = args[:server]
  end

  def register(*indirections)
    raise ArgumentError, "indirection names are required" if indirections.empty?
    indirections.flatten.each { |i| @routes[i.to_sym] = true }
  end
  
  def unregister(*indirections)
    indirections = @routes.keys if indirections.empty?
    indirections.flatten.each do |i|
      raise(ArgumentError, "indirection [%s] is not known" % i) unless @routes[i.to_sym]
      @routes.delete(i.to_sym)
    end
  end

  def listening?
    @listening
  end
  
  def listen
    raise "Cannot listen -- already listening" if listening?
    @listening = true
  end
  
  def unlisten
    raise "Cannot unlisten -- not currently listening" unless listening?
    @listening = false
  end
end
