class Puppet::Network::Server
	attr_reader :server_type, :http_server

    def initialize(args = {})
        @server_type = Puppet[:servertype] or raise "No servertype configuration found."  # e.g.,  WEBrick, Mongrel, etc.
	    @http_server_class = http_server_class_by_type(@server_type)
	    @listening = false
	    @routes = {}
	    self.register(args[:handlers]) if args[:handlers]
    end

    def register(*indirections)
	    raise ArgumentError, "Indirection names are required." if indirections.empty?
	    indirections.flatten.each { |i| @routes[i.to_sym] = true }
    end
  
    def unregister(*indirections)
        raise "Cannot unregister indirections while server is listening." if listening?
	    indirections = @routes.keys if indirections.empty?
	    
	    indirections.flatten.each do |i|
	        raise(ArgumentError, "Indirection [%s] is unknown." % i) unless @routes[i.to_sym]
        end
        
        indirections.flatten.each do |i|
	        @routes.delete(i.to_sym)
	    end
    end

    def listening?
	    @listening
    end
  
    def listen
	    raise "Cannot listen -- already listening." if listening?
	    initialize_http_server
	    self.http_server.listen(@routes.dup)
	    @listening = true
    end
  
    def unlisten
	    raise "Cannot unlisten -- not currently listening." unless listening?
	    self.http_server.unlisten   
	    @listening = false
    end

  private
  
    def initialize_http_server
	    @server = @http_server_class.new
    end
    
    def http_server_class_by_type(kind)
        # TODO:  this will become Puppet::Network::HTTP::WEBrick or Puppet::Network::HTTP::Mongrel
        Class.new
    end
end

